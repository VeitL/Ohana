//
//  DomainScheduleWriteKernel.swift
//  Ohana
//
//  Typed subject resolution, authorization, and persistence writer for
//  Event/Reminder schedules.
//

import Foundation
import SwiftData

nonisolated enum DomainScheduleSourceKind: Equatable {
    case userCommand
    case domainService
    case restore
    case cloudApply
    case system
}

nonisolated enum DomainScheduleAssigneeOverride: Equatable {
    case keepExisting
    case set(String?)

    func resolved(existing: String?) -> String? {
        switch self {
        case .keepExisting:
            existing
        case let .set(assigneeId):
            assigneeId
        }
    }
}

nonisolated struct DomainScheduleCreateIntent: Equatable {
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let eventType: String
    let relatedLink: DomainEntityLink
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let reminderLeadMinutes: Int?
    let explicitReminderDates: [Date]
    let assigneeId: String?
    let writeKind: MemberWriteKind
    let source: DomainScheduleSourceKind

    init(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        eventType: String = EventType.daily.rawValue,
        relatedEntityType: String = "",
        relatedEntityId: String = "",
        recurrenceDays: Int = 0,
        recurrenceEndDate: Date? = nil,
        reminderLeadMinutes: Int? = nil,
        reminderDates: [Date] = [],
        assigneeId: String? = nil,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind = .userCommand
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.eventType = eventType
        self.relatedLink = DomainEntityLink(rawType: relatedEntityType, rawId: relatedEntityId)
        self.recurrenceDays = recurrenceDays
        self.recurrenceEndDate = recurrenceDays > 0 ? recurrenceEndDate : nil
        self.reminderLeadMinutes = reminderLeadMinutes
        self.explicitReminderDates = reminderDates
        self.assigneeId = assigneeId
        self.writeKind = writeKind
        self.source = source
    }

    init(
        event: Event,
        startDate: Date? = nil,
        recurrenceEndDate: Date? = nil,
        assigneeOverride: DomainScheduleAssigneeOverride = .keepExisting,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind = .domainService
    ) {
        self.init(
            title: event.title,
            startDate: startDate ?? event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            eventType: event.eventType,
            relatedEntityType: event.relatedEntityType,
            relatedEntityId: event.relatedEntityId,
            recurrenceDays: event.recurrenceDays,
            recurrenceEndDate: recurrenceEndDate ?? event.recurrenceEndDate,
            assigneeId: assigneeOverride.resolved(existing: event.assigneeId),
            writeKind: writeKind,
            source: source
        )
    }

    func withAssigneeId(_ assigneeId: String?) -> DomainScheduleCreateIntent {
        DomainScheduleCreateIntent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            eventType: eventType,
            relatedEntityType: relatedLink.rawType,
            relatedEntityId: relatedLink.rawId,
            recurrenceDays: recurrenceDays,
            recurrenceEndDate: recurrenceEndDate,
            reminderLeadMinutes: reminderLeadMinutes,
            reminderDates: explicitReminderDates,
            assigneeId: assigneeId,
            writeKind: writeKind,
            source: source
        )
    }
}

typealias DomainScheduleResolution = DomainSubjectResolution

nonisolated struct DomainScheduleWriteToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainScheduleWrite {
    fileprivate let token: DomainScheduleWriteToken
    let mutationPlan: AuthorizedMutationPlan
    let intent: DomainScheduleCreateIntent
    let resolution: DomainScheduleResolution
    let disposition: MemberWriteDisposition

    fileprivate init(
        mutationPlan: AuthorizedMutationPlan,
        intent: DomainScheduleCreateIntent,
        resolution: DomainScheduleResolution,
        disposition: MemberWriteDisposition
    ) {
        self.token = DomainScheduleWriteToken()
        self.mutationPlan = mutationPlan
        self.intent = intent
        self.resolution = resolution
        self.disposition = disposition
    }

    var writesContent: Bool {
        disposition.writesContent
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }
}

nonisolated struct DomainScheduleWriteResult {
    let event: Event
    let reminders: [Reminder]
}

nonisolated struct DomainScheduleDeleteResult: Equatable {
    let eventID: UUID?
    let reminderIDs: [UUID]
    let notificationIdsToCancel: [String]
    let didDelete: Bool

    static let notDeleted = DomainScheduleDeleteResult(
        eventID: nil,
        reminderIDs: [],
        notificationIdsToCancel: [],
        didDelete: false
    )
}

nonisolated enum DomainScheduleEffectsDispatcher {
    static func dispatch(
        delete result: DomainScheduleDeleteResult,
        notifications: ReminderNotificationScheduling = OhanaNotifications.current
    ) {
        DomainRehydrateEffectsDispatcher.cancelNotifications(result.notificationIdsToCancel, notifications: notifications)
    }
}

nonisolated struct DomainScheduleMutationToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainScheduleMutation {
    fileprivate let token: DomainScheduleMutationToken
    let mutationPlan: AuthorizedMutationPlan
    let resolution: DomainScheduleResolution
    let disposition: MemberWriteDisposition
    let writeKind: MemberWriteKind
    let source: DomainScheduleSourceKind

    fileprivate init(
        mutationPlan: AuthorizedMutationPlan,
        resolution: DomainScheduleResolution,
        disposition: MemberWriteDisposition,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind
    ) {
        self.token = DomainScheduleMutationToken()
        self.mutationPlan = mutationPlan
        self.resolution = resolution
        self.disposition = disposition
        self.writeKind = writeKind
        self.source = source
    }

    var writesContent: Bool {
        disposition.writesContent
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }

    var allowsScheduleDeletion: Bool {
        writesContent || (writeKind == .lifecycle(.cleanupActiveSchedules) && allowsDerivedEffects)
    }
}

nonisolated enum DomainScheduleSubjectResolver {
    static func resolve(intent: DomainScheduleCreateIntent, context: ModelContext) -> DomainScheduleResolution {
        DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(link: intent.relatedLink, assigneeId: intent.assigneeId),
            context: context
        )
    }
}

nonisolated enum DomainScheduleWriteAuthorizer {
    static func authorizeCreate(
        intent: DomainScheduleCreateIntent,
        context: ModelContext
    ) -> AuthorizedDomainScheduleWrite? {
        guard let mutationPlan = authorizedMutationPlan(intent: intent, context: context) else { return nil }
        let authorizedIntent = mutationPlan.subjectRequest.assigneeId == intent.assigneeId
            ? intent
            : intent.withAssigneeId(mutationPlan.subjectRequest.assigneeId)

        return AuthorizedDomainScheduleWrite(
            mutationPlan: mutationPlan,
            intent: authorizedIntent,
            resolution: mutationPlan.subject,
            disposition: mutationPlan.disposition
        )
    }

    static func authorizeExistingEventMutation(
        event: Event,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind = .domainService,
        context: ModelContext
    ) -> AuthorizedDomainScheduleMutation? {
        let intent = DomainScheduleCreateIntent(
            event: event,
            writeKind: writeKind,
            source: source
        )
        guard let mutationPlan = authorizedMutationPlan(intent: intent, context: context) else { return nil }

        return AuthorizedDomainScheduleMutation(
            mutationPlan: mutationPlan,
            resolution: mutationPlan.subject,
            disposition: mutationPlan.disposition,
            writeKind: writeKind,
            source: source
        )
    }

    static func authorizeExistingReminderMutation(
        reminder: Reminder,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind = .domainService,
        context: ModelContext
    ) -> AuthorizedDomainScheduleMutation? {
        guard let event = reminder.event else {
            return authorizeUnscopedMutation(writeKind: writeKind, source: source, context: context)
        }
        return authorizeExistingEventMutation(
            event: event,
            writeKind: writeKind,
            source: source,
            context: context
        )
    }

    private static func authorizeUnscopedMutation(
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainScheduleMutation? {
        let request = DomainMutationAuthorizationRequest(
            scope: .schedule,
            source: DomainMutationSourceKind(scheduleSource: source),
            subjectRequest: DomainSubjectResolutionRequest(),
            writeKind: writeKind,
            unresolvedAssigneePolicy: .drop
        )
        guard let mutationPlan = DomainPolicyAuthorizer.authorize(request, context: context) else { return nil }
        return AuthorizedDomainScheduleMutation(
            mutationPlan: mutationPlan,
            resolution: mutationPlan.subject,
            disposition: mutationPlan.disposition,
            writeKind: writeKind,
            source: source
        )
    }

    static func authorizeExistingEventUpdate(
        event: Event,
        intent: DomainScheduleCreateIntent,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind = .domainService,
        context: ModelContext
    ) -> AuthorizedDomainScheduleMutation? {
        guard authorizeExistingEventMutation(
            event: event,
            writeKind: writeKind,
            source: source,
            context: context
        ) != nil else { return nil }

        guard let mutationPlan = authorizedMutationPlan(intent: intent, context: context) else { return nil }
        return AuthorizedDomainScheduleMutation(
            mutationPlan: mutationPlan,
            resolution: mutationPlan.subject,
            disposition: mutationPlan.disposition,
            writeKind: writeKind,
            source: source
        )
    }

    private static func authorizedMutationPlan(
        intent: DomainScheduleCreateIntent,
        context: ModelContext
    ) -> AuthorizedMutationPlan? {
        DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .schedule,
                source: DomainMutationSourceKind(scheduleSource: intent.source),
                subjectRequest: DomainSubjectResolutionRequest(
                    link: intent.relatedLink,
                    assigneeId: intent.assigneeId
                ),
                writeKind: intent.writeKind,
                unresolvedAssigneePolicy: .drop
            ),
            context: context
        )
    }
}

private extension DomainMutationSourceKind {
    nonisolated init(scheduleSource: DomainScheduleSourceKind) {
        switch scheduleSource {
        case .userCommand:
            self = .userCommand
        case .domainService:
            self = .domainService
        case .restore:
            self = .restore
        case .cloudApply:
            self = .cloudApply
        case .system:
            self = .system
        }
    }
}

nonisolated enum DomainScheduleWriter {
    static func makeUnpersistedEvent(intent: DomainScheduleCreateIntent) -> Event {
        constructEvent(intent: intent)
    }

    static func makeUnpersistedReminder(event: Event? = nil, scheduledAt: Date) -> Reminder {
        Reminder(event: event, scheduledAt: scheduledAt)
    }

    @discardableResult
    static func createEvent(
        plan: AuthorizedDomainScheduleWrite,
        context: ModelContext,
        calendar: Calendar = .current,
        maxReminderOccurrences: Int = 500
    ) -> DomainScheduleWriteResult {
        _ = plan.token
        plan.mutationPlan.consumeAuthorization()
        let intent = plan.intent
        let event = constructEvent(intent: intent)
        context.insert(event)

        let reminders = plan.allowsDerivedEffects
            ? createReminders(
                for: event,
                intent: intent,
                context: context,
                calendar: calendar,
                maxReminderOccurrences: maxReminderOccurrences
            )
            : []
        return DomainScheduleWriteResult(event: event, reminders: reminders)
    }

    private static func constructEvent(intent: DomainScheduleCreateIntent) -> Event {
        let event = Event(
            title: intent.title,
            startDate: intent.startDate,
            endDate: intent.endDate,
            isAllDay: intent.isAllDay,
            eventType: intent.eventType,
            relatedEntityType: intent.relatedLink.rawType,
            relatedEntityId: intent.relatedLink.rawId
        )
        event.recurrenceDays = intent.recurrenceDays
        event.recurrenceEndDate = intent.recurrenceEndDate
        event.assigneeId = intent.assigneeId
        return event
    }

    @discardableResult
    static func updateEvent(
        _ event: Event,
        intent: DomainScheduleCreateIntent,
        mutation: AuthorizedDomainScheduleMutation
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        let authorizedIntent = intent.withAssigneeId(mutation.mutationPlan.subjectRequest.assigneeId)
        event.title = authorizedIntent.title
        event.startDate = authorizedIntent.startDate
        event.endDate = authorizedIntent.endDate
        event.recurrenceDays = authorizedIntent.recurrenceDays
        event.recurrenceEndDate = authorizedIntent.recurrenceEndDate
        event.relatedEntityType = authorizedIntent.relatedLink.rawType
        event.relatedEntityId = authorizedIntent.relatedLink.rawId
        event.eventType = authorizedIntent.eventType
        event.isAllDay = authorizedIntent.isAllDay
        event.assigneeId = authorizedIntent.assigneeId
        return true
    }

    @discardableResult
    static func deleteEvent(
        _ event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> DomainScheduleDeleteResult {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.allowsScheduleDeletion else { return .notDeleted }
        let reminders = event.reminders
        let notificationIds = reminders.compactMap(cancellableNotificationId)
        for reminder in event.reminders {
            CloudSyncMutationRecorder.markDeleted(
                reminder,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(reminder)
        }
        CloudSyncMutationRecorder.markDeleted(
            event,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(event)
        return DomainScheduleDeleteResult(
            eventID: event.id,
            reminderIDs: reminders.map(\.id),
            notificationIdsToCancel: notificationIds,
            didDelete: true
        )
    }

    @discardableResult
    static func deleteReminder(
        _ reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        deletedAt: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> DomainScheduleDeleteResult {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.allowsScheduleDeletion else { return .notDeleted }
        let eventID = reminder.event?.id
        let notificationIds = cancellableNotificationId(for: reminder).map { [$0] } ?? []
        CloudSyncMutationRecorder.markDeleted(
            reminder,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        context.delete(reminder)
        return DomainScheduleDeleteResult(
            eventID: eventID,
            reminderIDs: [reminder.id],
            notificationIdsToCancel: notificationIds,
            didDelete: true
        )
    }

    @discardableResult
    static func truncateRecurringEvent(
        _ event: Event,
        recurrenceEndDate: Date,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        modifiedAt: Date = Date()
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.allowsScheduleDeletion else { return false }
        event.recurrenceDays = 0
        event.recurrenceEndDate = recurrenceEndDate
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: modifiedAt)
        return true
    }

    @discardableResult
    static func createReminder(
        for event: Event,
        scheduledAt: Date,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) -> Reminder? {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.allowsDerivedEffects else { return nil }
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(reminder)
        return reminder
    }

    @discardableResult
    static func createReminders(
        for event: Event,
        scheduledAt dates: [Date],
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) -> [Reminder] {
        dates.compactMap { date in
            createReminder(for: event, scheduledAt: date, mutation: mutation, context: context)
        }
    }

    @discardableResult
    static func setEventOccurrenceCompletion(
        _ event: Event,
        occurrenceDate: Date,
        isCompleted: Bool,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext,
        modifiedAt: Date
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        event.setOccurrenceMarkedComplete(isCompleted, on: occurrenceDate)
        if event.recurrenceDays <= 0 {
            event.isCompleted = isCompleted
        }
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: modifiedAt)
        return true
    }

    @discardableResult
    static func completeReminder(
        _ reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        completedBy humanId: String?,
        completedAt: Date,
        context: ModelContext
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        reminder.statusEnum = .completed
        reminder.completedAt = completedAt
        reminder.completedBy = humanId ?? ""
        if let event = reminder.event {
            event.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: completedAt)
        }
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: completedAt)
        return true
    }

    @discardableResult
    static func skipReminder(
        _ reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        skippedBy humanId: String?,
        skippedAt: Date,
        context: ModelContext
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        reminder.statusEnum = .skipped
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: skippedAt)
        return true
    }

    @discardableResult
    static func failReminder(
        _ reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        failedAt: Date,
        context: ModelContext
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        reminder.statusEnum = .failed
        reminder.completedAt = nil
        reminder.completedBy = ""
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: failedAt)
        return true
    }

    @discardableResult
    static func reopenReminder(
        _ reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        reopenedBy humanId: String?,
        reopenedAt: Date,
        context: ModelContext
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        if let event = reminder.event {
            event.setOccurrenceMarkedComplete(false, on: reminder.scheduledAt)
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: reopenedAt)
        }
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: reopenedAt)
        return true
    }

    @discardableResult
    static func resetReminderToPending(
        _ reminder: Reminder,
        scheduledAt newScheduledAt: Date? = nil,
        mutation: AuthorizedDomainScheduleMutation,
        resetBy humanId: String? = nil,
        resetAt: Date,
        context: ModelContext
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        let occurrenceDate = reminder.scheduledAt
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        if let newScheduledAt {
            reminder.scheduledAt = newScheduledAt
        }
        if let event = reminder.event {
            event.setOccurrenceMarkedComplete(false, on: occurrenceDate)
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: resetAt)
        }
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: resetAt)
        return true
    }

    @discardableResult
    static func snoozeReminderOneDay(
        _ reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        snoozedBy humanId: String?,
        snoozedAt: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.scheduledAt = calendar.date(byAdding: .day, value: 1, to: reminder.scheduledAt)
            ?? snoozedAt.addingTimeInterval(86400)
        CloudSyncMutationRecorder.markModified(reminder, context: context, modifiedAt: snoozedAt)
        return true
    }

    private static func createReminders(
        for event: Event,
        intent: DomainScheduleCreateIntent,
        context: ModelContext,
        calendar: Calendar,
        maxReminderOccurrences: Int
    ) -> [Reminder] {
        if !intent.explicitReminderDates.isEmpty {
            return intent.explicitReminderDates.prefix(maxReminderOccurrences).map { scheduled in
                let reminder = Reminder(event: event, scheduledAt: scheduled)
                context.insert(reminder)
                return reminder
            }
        }
        guard let leadMinutes = intent.reminderLeadMinutes else { return [] }
        if intent.recurrenceDays >= 1, let recurrenceEndDate = intent.recurrenceEndDate {
            var reminders: [Reminder] = []
            var cursor = intent.startDate
            var safetyCount = 0
            while cursor <= recurrenceEndDate, safetyCount < maxReminderOccurrences {
                let scheduled = calendar.date(byAdding: .minute, value: -leadMinutes, to: cursor) ?? cursor
                let reminder = Reminder(event: event, scheduledAt: scheduled)
                context.insert(reminder)
                reminders.append(reminder)

                guard let next = calendar.date(byAdding: .day, value: intent.recurrenceDays, to: cursor),
                      next > cursor else {
                    break
                }
                cursor = next
                safetyCount += 1
            }
            return reminders
        }

        let scheduled = calendar.date(byAdding: .minute, value: -leadMinutes, to: intent.startDate) ?? intent.startDate
        let reminder = Reminder(event: event, scheduledAt: scheduled)
        context.insert(reminder)
        return [reminder]
    }

    private static func cancellableNotificationId(for reminder: Reminder) -> String? {
        let trimmed = reminder.notificationId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
