//
//  DomainRehydrateWriteKernel.swift
//  Ohana
//
//  Central rehydrate capability and writers for backup/cloud records.
//

import Foundation
import SwiftData

nonisolated enum DomainRehydrateSourceKind: Equatable {
    case backupRestore
    case cloudApply

    var mutationSource: DomainMutationSourceKind {
        switch self {
        case .backupRestore:
            .restore
        case .cloudApply:
            .cloudApply
        }
    }
}

nonisolated enum DomainRehydrateDisposition: Equatable {
    case normalized
    case legacyHistoryOnly
    case quarantined(unregisteredType: String)
    case dropEffects

    var allowsPersistence: Bool {
        true
    }

    var allowsDerivedEffects: Bool {
        false
    }
}

nonisolated struct DomainScheduleRehydrateEventSnapshot: Equatable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let eventType: String
    let relatedEntityType: String
    let relatedEntityId: String
    let recurrenceDays: Int
    let recurrenceEndDate: Date?
    let isCompleted: Bool
    let completedOccurrences: [String]
    let createdAt: Date
    let assigneeId: String?
    let feedRuleKindRaw: String
    let foodKindRaw: String
    let feedAmountGrams: Double
    let feedPlanGroupId: String

    var subjectRequest: DomainSubjectResolutionRequest {
        DomainSubjectResolutionRequest(
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityId,
            assigneeId: assigneeId
        )
    }
}

nonisolated struct DomainScheduleRehydrateReminderSnapshot: Equatable {
    let id: UUID
    let scheduledAt: Date
    let status: String
    let notificationId: String
    let eventId: UUID?
    let completedAt: Date?
    let completedBy: String
    let createdAt: Date
}

nonisolated struct DomainCareLedgerRehydrateSnapshot: Equatable {
    let id: UUID
    let occurredAt: Date
    let actorKind: String
    let actorId: String?
    let subjectKind: String
    let subjectId: String?
    let eventKind: String
    let actionType: String
    let amountValue: Double
    let amountUnit: String
    let note: String
    let source: String
    let sourceEventId: String?
    let sourceReminderId: String?
    let legacyModelName: String?
    let legacyModelId: String?
    let coconutDelta: Int
    let rewardLogId: String?
    let privacyFieldRaw: String?
    let metadataJSON: String
    let createdAt: Date

    var subjectRequest: DomainSubjectResolutionRequest {
        switch CareLedgerSubjectKind(rawValue: subjectKind) ?? .unknown {
        case .pet:
            DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: subjectId ?? ""
            )
        case .human:
            DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: subjectId ?? ""
            )
        case .plant, .household, .system, .unknown:
            DomainSubjectResolutionRequest()
        }
    }
}

nonisolated struct DomainRehydrateToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainRehydratePlan {
    fileprivate let token: DomainRehydrateToken
    let source: DomainRehydrateSourceKind
    let scope: DomainMutationScope
    let subject: DomainSubjectResolution
    let disposition: DomainRehydrateDisposition

    fileprivate init(
        source: DomainRehydrateSourceKind,
        scope: DomainMutationScope,
        subject: DomainSubjectResolution,
        disposition: DomainRehydrateDisposition
    ) {
        self.token = DomainRehydrateToken()
        self.source = source
        self.scope = scope
        self.subject = subject
        self.disposition = disposition
    }

    func consumeAuthorization() {
        _ = token
    }
}

nonisolated enum DomainRehydrateAuthorizer {
    static func authorizeSchedule(
        snapshot: DomainScheduleRehydrateEventSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        authorize(
            source: source,
            scope: .rehydrate,
            request: snapshot.subjectRequest,
            context: context
        )
    }

    static func authorizeReminder(
        event: Event?,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        let request = event.map(DomainSubjectResolutionRequest.init(event:)) ?? DomainSubjectResolutionRequest()
        return authorize(source: source, scope: .rehydrate, request: request, context: context)
    }

    static func authorizeCareLedger(
        snapshot: DomainCareLedgerRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        authorize(
            source: source,
            scope: .rehydrate,
            request: snapshot.subjectRequest,
            context: context
        )
    }

    static func authorizeSubject(
        request: DomainSubjectResolutionRequest,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        authorize(source: source, scope: .rehydrate, request: request, context: context)
    }

    private static func authorize(
        source: DomainRehydrateSourceKind,
        scope: DomainMutationScope,
        request: DomainSubjectResolutionRequest,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        let subject = DomainSubjectResolver.resolve(request: request, context: context)
        return AuthorizedDomainRehydratePlan(
            source: source,
            scope: scope,
            subject: subject,
            disposition: disposition(for: subject)
        )
    }

    private static func disposition(for subject: DomainSubjectResolution) -> DomainRehydrateDisposition {
        if let unregisteredType = subject.unregisteredType {
            return .quarantined(unregisteredType: unregisteredType)
        }
        if subject.unresolvedOwner || subject.unresolvedAssignee {
            return .legacyHistoryOnly
        }
        return .normalized
    }
}

nonisolated struct DomainScheduleRehydrateEventResult {
    let event: Event
    let inserted: Bool
    let plan: AuthorizedDomainRehydratePlan
}

nonisolated struct DomainScheduleRehydrateReminderResult {
    let reminder: Reminder
    let inserted: Bool
    let plan: AuthorizedDomainRehydratePlan
}

nonisolated enum DomainScheduleRehydrateWriter {
    @discardableResult
    static func upsertEvent(
        snapshot: DomainScheduleRehydrateEventSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainScheduleRehydrateEventResult {
        let plan = DomainRehydrateAuthorizer.authorizeSchedule(
            snapshot: snapshot,
            source: source,
            context: context
        )
        guard plan.disposition.allowsPersistence else {
            throw DomainRehydrateWriteError.persistenceDenied
        }

        let event: Event
        let inserted: Bool
        if let existing = try fetchEvent(id: snapshot.id, context: context) {
            event = existing
            inserted = false
        } else {
            event = Event(
                title: snapshot.title,
                startDate: snapshot.startDate,
                endDate: snapshot.endDate,
                isAllDay: snapshot.isAllDay,
                eventType: snapshot.eventType,
                relatedEntityType: snapshot.relatedEntityType,
                relatedEntityId: snapshot.relatedEntityId
            )
            event.id = snapshot.id
            context.insert(event)
            inserted = true
        }

        apply(snapshot: snapshot, to: event, plan: plan)
        return DomainScheduleRehydrateEventResult(event: event, inserted: inserted, plan: plan)
    }

    @discardableResult
    static func upsertReminder(
        snapshot: DomainScheduleRehydrateReminderSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainScheduleRehydrateReminderResult {
        let linkedEvent = try snapshot.eventId.flatMap { try fetchEvent(id: $0, context: context) }
        let plan = DomainRehydrateAuthorizer.authorizeReminder(
            event: linkedEvent,
            source: source,
            context: context
        )
        guard plan.disposition.allowsPersistence else {
            throw DomainRehydrateWriteError.persistenceDenied
        }

        let reminder: Reminder
        let inserted: Bool
        if let existing = try fetchReminder(id: snapshot.id, context: context) {
            reminder = existing
            inserted = false
        } else {
            reminder = Reminder(event: linkedEvent, scheduledAt: snapshot.scheduledAt)
            reminder.id = snapshot.id
            context.insert(reminder)
            inserted = true
        }

        apply(snapshot: snapshot, event: linkedEvent, to: reminder, plan: plan)
        return DomainScheduleRehydrateReminderResult(reminder: reminder, inserted: inserted, plan: plan)
    }

    private static func apply(
        snapshot: DomainScheduleRehydrateEventSnapshot,
        to event: Event,
        plan: AuthorizedDomainRehydratePlan
    ) {
        plan.consumeAuthorization()
        event.title = snapshot.title
        event.startDate = snapshot.startDate
        event.endDate = snapshot.endDate
        event.isAllDay = snapshot.isAllDay
        event.eventType = snapshot.eventType
        event.relatedEntityType = snapshot.relatedEntityType
        event.relatedEntityId = snapshot.relatedEntityId
        event.recurrenceDays = snapshot.recurrenceDays
        event.recurrenceEndDate = snapshot.recurrenceEndDate
        event.isCompleted = snapshot.isCompleted
        event.completedOccurrences = snapshot.completedOccurrences
        event.createdAt = snapshot.createdAt
        event.assigneeId = snapshot.assigneeId
        event.feedRuleKindRaw = snapshot.feedRuleKindRaw
        event.foodKindRaw = snapshot.foodKindRaw
        event.feedAmountGrams = snapshot.feedAmountGrams
        event.feedPlanGroupId = snapshot.feedPlanGroupId
    }

    private static func apply(
        snapshot: DomainScheduleRehydrateReminderSnapshot,
        event: Event?,
        to reminder: Reminder,
        plan: AuthorizedDomainRehydratePlan
    ) {
        plan.consumeAuthorization()
        reminder.event = event
        reminder.scheduledAt = snapshot.scheduledAt
        reminder.status = snapshot.status
        reminder.notificationId = snapshot.notificationId
        reminder.completedAt = snapshot.completedAt
        reminder.completedBy = snapshot.completedBy
        reminder.createdAt = snapshot.createdAt
    }

    private static func fetchEvent(id: UUID, context: ModelContext) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchReminder(id: UUID, context: ModelContext) throws -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

nonisolated struct DomainCareLedgerRehydrateResult {
    let event: CareLedgerEvent
    let inserted: Bool
    let plan: AuthorizedDomainRehydratePlan
}

nonisolated enum DomainCareLedgerRehydrateWriter {
    @discardableResult
    static func upsertCareLedgerEvent(
        snapshot: DomainCareLedgerRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareLedgerRehydrateResult {
        let plan = DomainRehydrateAuthorizer.authorizeCareLedger(
            snapshot: snapshot,
            source: source,
            context: context
        )
        guard plan.disposition.allowsPersistence else {
            throw DomainRehydrateWriteError.persistenceDenied
        }

        let event: CareLedgerEvent
        let inserted: Bool
        if let existing = try fetchCareLedgerEvent(id: snapshot.id, context: context) {
            event = existing
            inserted = false
        } else {
            event = CareLedgerEvent(
                id: snapshot.id,
                occurredAt: snapshot.occurredAt,
                actorKind: CareLedgerActorKind(rawValue: snapshot.actorKind) ?? .unknown,
                actorId: snapshot.actorId,
                subjectKind: CareLedgerSubjectKind(rawValue: snapshot.subjectKind) ?? .unknown,
                subjectId: snapshot.subjectId,
                eventKind: CareLedgerEventKind(rawValue: snapshot.eventKind) ?? .unknown,
                actionType: snapshot.actionType,
                amountValue: snapshot.amountValue,
                amountUnit: snapshot.amountUnit,
                note: snapshot.note,
                source: CareLedgerSource(rawValue: snapshot.source) ?? .importData,
                sourceEventId: snapshot.sourceEventId,
                sourceReminderId: snapshot.sourceReminderId,
                legacyModelName: snapshot.legacyModelName,
                legacyModelId: snapshot.legacyModelId,
                coconutDelta: snapshot.coconutDelta,
                rewardLogId: snapshot.rewardLogId,
                privacyFieldRaw: snapshot.privacyFieldRaw,
                metadataJSON: snapshot.metadataJSON,
                createdAt: snapshot.createdAt
            )
            context.insert(event)
            inserted = true
        }

        apply(snapshot: snapshot, to: event, plan: plan)
        return DomainCareLedgerRehydrateResult(event: event, inserted: inserted, plan: plan)
    }

    private static func apply(
        snapshot: DomainCareLedgerRehydrateSnapshot,
        to event: CareLedgerEvent,
        plan: AuthorizedDomainRehydratePlan
    ) {
        plan.consumeAuthorization()
        event.occurredAt = snapshot.occurredAt
        event.actorKind = snapshot.actorKind
        event.actorId = snapshot.actorId
        event.subjectKind = snapshot.subjectKind
        event.subjectId = snapshot.subjectId
        event.eventKind = snapshot.eventKind
        event.actionType = snapshot.actionType
        event.amountValue = snapshot.amountValue
        event.amountUnit = snapshot.amountUnit
        event.note = snapshot.note
        event.source = snapshot.source
        event.sourceEventId = snapshot.sourceEventId
        event.sourceReminderId = snapshot.sourceReminderId
        event.legacyModelName = snapshot.legacyModelName
        event.legacyModelId = snapshot.legacyModelId
        event.coconutDelta = snapshot.coconutDelta
        event.rewardLogId = snapshot.rewardLogId
        event.privacyFieldRaw = snapshot.privacyFieldRaw
        event.metadataJSON = snapshot.metadataJSON
        event.createdAt = snapshot.createdAt
    }

    private static func fetchCareLedgerEvent(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

nonisolated enum DomainRehydrateWriteError: Error {
    case persistenceDenied
}
