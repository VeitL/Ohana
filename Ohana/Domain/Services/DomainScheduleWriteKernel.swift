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
        context: ModelContext
    ) -> Bool {
        _ = mutation.token
        mutation.mutationPlan.consumeAuthorization()
        guard mutation.writesContent else { return false }
        for reminder in event.reminders {
            CloudSyncMutationRecorder.markDeleted(reminder, context: context)
        }
        CloudSyncMutationRecorder.markDeleted(event, context: context)
        context.delete(event)
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
}
