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

nonisolated struct DomainScheduleResolution: Equatable {
    let link: DomainEntityLink
    let role: DomainEntityLinkRole
    let owner: DomainMemberReference?
    let assignee: DomainMemberReference?
    let displayTarget: DomainMemberReference?
    let unresolvedOwner: Bool
    let unresolvedAssignee: Bool

    var lifecycleTargets: [DomainMemberReference] {
        var targets: [DomainMemberReference] = []
        if let owner { targets.append(owner) }
        if let assignee, assignee != owner { targets.append(assignee) }
        return targets
    }
}

nonisolated struct DomainScheduleWriteToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainScheduleWrite {
    fileprivate let token: DomainScheduleWriteToken
    let intent: DomainScheduleCreateIntent
    let resolution: DomainScheduleResolution
    let disposition: MemberWriteDisposition

    fileprivate init(
        intent: DomainScheduleCreateIntent,
        resolution: DomainScheduleResolution,
        disposition: MemberWriteDisposition
    ) {
        self.token = DomainScheduleWriteToken()
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
    let resolution: DomainScheduleResolution
    let disposition: MemberWriteDisposition
    let writeKind: MemberWriteKind
    let source: DomainScheduleSourceKind

    fileprivate init(
        resolution: DomainScheduleResolution,
        disposition: MemberWriteDisposition,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind
    ) {
        self.token = DomainScheduleMutationToken()
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
        let link = intent.relatedLink
        let role = DomainEntityLinkRegistry.role(for: link)
        let owner = ownerReference(for: link, role: role, context: context)
        let assignee = assigneeReference(assigneeId: intent.assigneeId)
        return DomainScheduleResolution(
            link: link,
            role: role,
            owner: owner,
            assignee: assignee,
            displayTarget: owner ?? assignee,
            unresolvedOwner: role.isMemberScoped && owner == nil,
            unresolvedAssignee: hasExplicitAssignee(intent.assigneeId) && assignee == nil
        )
    }

    private static func ownerReference(
        for link: DomainEntityLink,
        role: DomainEntityLinkRole,
        context: ModelContext
    ) -> DomainMemberReference? {
        switch role {
        case .directPet, .petAutoFeeder, .petWaterPlan:
            return UUID(uuidString: link.trimmedId).map(DomainMemberReference.pet)
        case .petFoodStock:
            return DomainEntityLinkRegistry.petIdFromCompoundStockId(link.trimmedId).map(DomainMemberReference.pet)
        case .petInsurance:
            guard let insuranceId = UUID(uuidString: link.trimmedId),
                  let insurance = fetchPetInsurance(id: insuranceId, context: context),
                  let petId = insurance.pet?.id else {
                return nil
            }
            return .pet(petId)
        case .petMedicationPlan, .petMedicationDose:
            guard let medicationId = UUID(uuidString: link.trimmedId),
                  let medication = fetchPetMedication(id: medicationId, context: context),
                  let petId = medication.pet?.id else {
                return nil
            }
            return .pet(petId)
        case .directHuman, .humanNote:
            return UUID(uuidString: link.trimmedId).map(DomainMemberReference.human)
        case .humanMedicationPlan:
            guard let medicationId = UUID(uuidString: link.trimmedId),
                  let medication = fetchHumanMedication(id: medicationId, context: context),
                  let humanId = UUID(uuidString: medication.humanId) else {
                return nil
            }
            return .human(humanId)
        case .directPlant, .unscoped, .unknown:
            return nil
        }
    }

    private static func assigneeReference(assigneeId: String?) -> DomainMemberReference? {
        guard let assigneeId,
              !assigneeId.isEmpty,
              let id = UUID(uuidString: assigneeId) else {
            return nil
        }
        return .human(id)
    }

    private static func hasExplicitAssignee(_ assigneeId: String?) -> Bool {
        guard let assigneeId else { return false }
        return !assigneeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func fetchPetMedication(id: UUID, context: ModelContext) -> PetMedication? {
        var descriptor = FetchDescriptor<PetMedication>(
            predicate: #Predicate<PetMedication> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchHumanMedication(id: UUID, context: ModelContext) -> HumanMedication? {
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchPetInsurance(id: UUID, context: ModelContext) -> PetInsurance? {
        var descriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

nonisolated enum DomainScheduleWriteAuthorizer {
    static func authorizeCreate(
        intent: DomainScheduleCreateIntent,
        context: ModelContext
    ) -> AuthorizedDomainScheduleWrite? {
        let authorizationInput = normalizedAuthorizationInput(intent: intent, context: context)
        guard let disposition = authorizedDisposition(
            resolution: authorizationInput.resolution,
            writeKind: authorizationInput.intent.writeKind,
            context: context
        ) else { return nil }

        return AuthorizedDomainScheduleWrite(
            intent: authorizationInput.intent,
            resolution: authorizationInput.resolution,
            disposition: disposition
        )
    }

    static func authorizeExistingEventMutation(
        event: Event,
        writeKind: MemberWriteKind,
        source: DomainScheduleSourceKind = .domainService,
        context: ModelContext
    ) -> AuthorizedDomainScheduleMutation? {
        let intent = DomainScheduleCreateIntent(
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            eventType: event.eventType,
            relatedEntityType: event.relatedEntityType,
            relatedEntityId: event.relatedEntityId,
            recurrenceDays: event.recurrenceDays,
            recurrenceEndDate: event.recurrenceEndDate,
            assigneeId: event.assigneeId,
            writeKind: writeKind,
            source: source
        )
        let resolution = normalizedAuthorizationInput(intent: intent, context: context).resolution
        guard let disposition = authorizedDisposition(
            resolution: resolution,
            writeKind: writeKind,
            context: context
        ) else { return nil }

        return AuthorizedDomainScheduleMutation(
            resolution: resolution,
            disposition: disposition,
            writeKind: writeKind,
            source: source
        )
    }

    private static func normalizedAuthorizationInput(
        intent: DomainScheduleCreateIntent,
        context: ModelContext
    ) -> (intent: DomainScheduleCreateIntent, resolution: DomainScheduleResolution) {
        let resolution = DomainScheduleSubjectResolver.resolve(intent: intent, context: context)
        guard resolution.unresolvedAssignee else {
            return (intent, resolution)
        }
        let unassignedIntent = intent.withAssigneeId(nil)
        return (
            unassignedIntent,
            DomainScheduleSubjectResolver.resolve(intent: unassignedIntent, context: context)
        )
    }

    private static func authorizedDisposition(
        resolution: DomainScheduleResolution,
        writeKind: MemberWriteKind,
        context: ModelContext
    ) -> MemberWriteDisposition? {
        guard !resolution.unresolvedOwner else { return nil }
        guard !resolution.unresolvedAssignee else { return nil }

        var disposition: MemberWriteDisposition = .activeWritable
        if let ownerDisposition = memberDisposition(for: resolution.owner, writeKind: writeKind, context: context) {
            disposition = ownerDisposition
        }
        guard disposition.writesContent else { return nil }

        if let assigneeDisposition = memberDisposition(for: resolution.assignee, writeKind: .care, context: context),
           !assigneeDisposition.allowsDerivedEffects {
            return nil
        }
        return disposition
    }

    private static func memberDisposition(
        for reference: DomainMemberReference?,
        writeKind: MemberWriteKind,
        context: ModelContext
    ) -> MemberWriteDisposition? {
        guard let reference else { return nil }
        switch reference {
        case let .pet(id):
            guard let pet = fetchPet(id: id, context: context) else { return .missingMemberTarget }
            return MemberLifecycleGate.disposition(pet: pet, writeKind: writeKind)
        case let .human(id):
            guard let human = fetchHuman(id: id, context: context) else { return .missingMemberTarget }
            return MemberLifecycleGate.disposition(human: human, writeKind: writeKind)
        }
    }

    private static func fetchPet(id: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchHuman(id: UUID, context: ModelContext) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
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
    static func createReminder(
        for event: Event,
        scheduledAt: Date,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) -> Reminder? {
        _ = mutation.token
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
