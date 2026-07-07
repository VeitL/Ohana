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
        let shouldReplaceDeferredCalendarDuplicate = shouldReplaceDeferredCalendarDuplicate(
            reminder: reminder,
            policyDecision: policyDecision,
            existingNotificationIds: existingIds,
            context: context
        )
        if shouldReplaceDeferredCalendarDuplicate {
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        }
        let schedulingExistingIds = shouldReplaceDeferredCalendarDuplicate
            ? existingIds.subtracting([reminder.notificationId])
            : existingIds
        let result = await withCheckedContinuation { continuation in
            OhanaNotifications.current.schedule(
                reminder: reminder,
                deliveryDate: deliveryDate,
                existingNotificationIds: schedulingExistingIds
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
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                reminder: reminder,
                writeKind: .care,
                source: .system,
                context: context
            ) else { continue }
            let didMutate: Bool
            if reminder.event?.eventType == EventType.foodChange.rawValue {
                didMutate = DomainScheduleWriter.failReminder(
                    reminder,
                    mutation: mutation,
                    failedAt: now,
                    context: context
                )
                actionType = "compensateFailed"
            } else {
                didMutate = DomainScheduleWriter.skipReminder(
                    reminder,
                    mutation: mutation,
                    skippedBy: nil,
                    skippedAt: now,
                    context: context
                )
                actionType = "compensateSkipped"
            }
            guard didMutate else { continue }
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            careLedger.recordReminderState(
                reminder: reminder,
                actionType: actionType,
                actorId: nil,
                source: .service,
                context: context,
                save: false
            )
        }
        _ = saveReminderSchedulingChanges(context: context)
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
                careLedger.recordReminderState(
                    reminder: reminder,
                    actionType: "dedupeRemoved",
                    actorId: nil,
                    source: .service,
                    context: context,
                    save: false
                )
                guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
                    reminder: reminder,
                    writeKind: .lifecycle(.cleanupActiveSchedules),
                    source: .domainService,
                    context: context
                ) else { continue }
                let result = DomainScheduleWriter.deleteReminder(reminder, mutation: mutation, context: context, deletedAt: now)
                DomainScheduleEffectsDispatcher.dispatch(delete: result)
                didChange = result.didDelete || didChange
            } else {
                seen.insert(key)
                kept.append(reminder)
            }
        }
        if didChange {
            _ = saveReminderSchedulingChanges(context: context)
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
        let subject = careLedger.subjectInfo(from: reminder.event, context: context)
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
            save: false
        )
        if save {
            _ = saveReminderSchedulingChanges(context: context)
        }
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
        let orderedReminders = remindersToKeep.sorted {
            let lhsDecision = policyDecisions[$0.id]
            let rhsDecision = policyDecisions[$1.id]
            return NotificationPendingBudget.shouldScheduleBefore(
                lhsDeliveryDate: lhsDecision?.deliveryDate ?? $0.scheduledAt,
                lhsClassification: schedulingClassification(for: $0, decision: lhsDecision),
                lhsCreatedAt: $0.createdAt,
                rhsDeliveryDate: rhsDecision?.deliveryDate ?? $1.scheduledAt,
                rhsClassification: schedulingClassification(for: $1, decision: rhsDecision),
                rhsCreatedAt: $1.createdAt
            )
        }
        let plantBatchCareSummaries = plantBatchCareSummaries(
            reminders: remindersToKeep,
            policyDecisions: policyDecisions
        )
        let plantBatchScheduler = OhanaNotifications.current as? PlantBatchCareSummaryNotificationScheduling
        var plantBatchCareSummaryByReminderID: [UUID: PlantBatchCareNotificationSummary] = [:]
        var knownNotificationIds = await OhanaNotifications.current.pendingNotificationIds()
        if let plantBatchScheduler {
            let summaries = plantBatchCareSummaries
            for summary in summaries {
                let result = plantBatchScheduler.schedulePlantBatchCareSummary(
                    summary,
                    existingNotificationIds: knownNotificationIds
                )
                guard result.didRegisterNotification || result == .skippedDuplicate else {
                    continue
                }
                if result.didRegisterNotification {
                    knownNotificationIds.insert(summary.notificationId)
                }
                for id in summary.reminderIDs {
                    plantBatchCareSummaryByReminderID[id] = summary
                }
            }
        }
        for (index, reminder) in orderedReminders.enumerated() {
            guard !Task.isCancelled else {
                _ = saveReminderSchedulingChanges(context: context)
                return
            }
            if let summary = plantBatchCareSummaryByReminderID[reminder.id],
               let event = reminder.event {
                OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
                knownNotificationIds.remove(reminder.notificationId)
                let classification = NotificationDeliveryPolicy.classification(for: event)
                _ = await scheduleIfNeeded(
                    reminder: reminder,
                    context: context,
                    source: source,
                    existingNotificationIds: knownNotificationIds,
                    operation: operation,
                    saveLedger: false,
                    careLedger: careLedger,
                    policyDecision: .merged(
                        classification: classification,
                        scheduledAt: reminder.scheduledAt,
                        mergedInto: summary.anchorReminderID
                    )
                )
                continue
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
        _ = saveReminderSchedulingChanges(context: context)
    }

    @MainActor
    @discardableResult
    private static func saveReminderSchedulingChanges(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }

    private static func schedulingClassification(
        for reminder: Reminder,
        decision: NotificationDeliveryDecision?
    ) -> NotificationDeliveryClassification {
        if let decision {
            return decision.classification
        }
        guard let event = reminder.event else {
            return NotificationDeliveryClassification(tier: .ambient, category: .calendar, mergeAllowed: false)
        }
        return NotificationDeliveryPolicy.classification(for: event)
    }

    private static func plantBatchCareSummaries(
        reminders: [Reminder],
        policyDecisions: [UUID: NotificationDeliveryDecision],
        calendar: Calendar = .current
    ) -> [PlantBatchCareNotificationSummary] {
        var buckets: [String: [(reminder: Reminder, deliveryDate: Date, careType: PlantCareType, plantID: UUID?)]] = [:]
        for reminder in reminders {
            guard let event = reminder.event,
                  PlantReminderPreferenceStore.isPlantCareEvent(event),
                  let careType = PlantReminderPreferenceStore.careType(forEventType: event.eventType),
                  let decision = policyDecisions[reminder.id],
                  case let .deliver(deliveryDate, classification, _) = decision,
                  classification.category == .plantCare else {
                continue
            }
            let key = [
                dayKey(for: deliveryDate, calendar: calendar),
                careType.rawValue
            ].joined(separator: "|")
            buckets[key, default: []].append((
                reminder: reminder,
                deliveryDate: deliveryDate,
                careType: careType,
                plantID: DomainEntityLinkRegistry.plantId(for: event)
            ))
        }

        return buckets.values.compactMap { items in
            let sorted = items.sorted {
                if $0.deliveryDate != $1.deliveryDate {
                    return $0.deliveryDate < $1.deliveryDate
                }
                return $0.reminder.createdAt < $1.reminder.createdAt
            }
            guard sorted.count > 1,
                  let first = sorted.first else { return nil }
            let dayStart = calendar.startOfDay(for: first.deliveryDate)
            let plantIDs = Set(sorted.compactMap(\.plantID))
            let plantCount = plantIDs.isEmpty ? sorted.count : plantIDs.count
            return PlantBatchCareNotificationSummary(
                notificationId: "plant-batch-care-\(first.careType.rawValue)-\(Int(dayStart.timeIntervalSince1970))",
                deliveryDate: first.deliveryDate,
                careType: first.careType,
                plantCount: plantCount,
                taskCount: sorted.count,
                anchorReminderID: first.reminder.id,
                reminderIDs: sorted.map(\.reminder.id)
            )
        }
        .sorted {
            if $0.deliveryDate != $1.deliveryDate {
                return $0.deliveryDate < $1.deliveryDate
            }
            return $0.careType.rawValue < $1.careType.rawValue
        }
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    @MainActor
    private static func shouldReplaceDeferredCalendarDuplicate(
        reminder: Reminder,
        policyDecision: NotificationDeliveryDecision?,
        existingNotificationIds: Set<String>,
        context: ModelContext
    ) -> Bool {
        guard existingNotificationIds.contains(reminder.notificationId),
              let policyDecision,
              case let .deliver(_, classification, deferred) = policyDecision,
              classification.category == .calendar,
              !deferred else {
            return false
        }

        let reminderId = reminder.id.uuidString
        let reminderKind = CareLedgerEventKind.reminder.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.sourceReminderId == reminderId &&
                    event.eventKind == reminderKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 12

        guard let entries = try? context.fetch(descriptor) else { return false }
        for entry in entries {
            switch entry.actionType {
            case "scheduleSuccess", "refillSuccess":
                return false
            case "scheduleDeferred", "refillDeferred":
                if entry.metadataJSON.contains("\"category\":\"calendar\"") &&
                    entry.metadataJSON.contains("\"deferred\":true") {
                    return true
                }
            default:
                continue
            }
        }
        return false
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
}
