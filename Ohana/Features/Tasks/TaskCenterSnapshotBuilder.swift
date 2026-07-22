//
//  TaskCenterSnapshotBuilder.swift
//  Ohana
//
//  Builds bounded, value-only Task Center projections from domain facts.
//

import Foundation

nonisolated enum TaskCenterSnapshotBuilder {
    /// Repeating schedules expose one current actionable occurrence in the center.
    /// Older occurrences remain available in Calendar; this keeps the high-frequency
    /// task surface bounded while preserving the existing completion semantics.
    private static let recurringOverdueLookbackDays = 14

    private struct ItemBuildContext {
        let pets: [Pet]
        let humans: [Human]
        let plants: [Plant]
        let insurances: [PetInsurance]
        let petMedications: [PetMedication]
        let humanMedications: [HumanMedication]
        let reminders: [Reminder]
        let remindersByID: [UUID: Reminder]
        let eventsByID: [UUID: Event]
        let activeHumanId: String?
        let now: Date
        let calendar: Calendar
    }

    private struct PendingEventState {
        var occurrencesByEventID: [UUID: [CalendarEventOccurrence]] = [:]
        var todayTaskKeys: Set<String> = []
        var completedTodayTaskKeys: Set<String> = []
    }

    private struct ItemBuckets {
        var overdue: [TaskCenterItemSnapshot] = []
        var today: [TaskCenterItemSnapshot] = []
        var upcoming: [TaskCenterItemSnapshot] = []
        var unscheduled: [TaskCenterItemSnapshot] = []

        mutating func append(
            _ item: TaskCenterItemSnapshot,
            dueAt: Date?,
            today startOfToday: Date,
            calendar: Calendar
        ) {
            guard let dueAt else {
                unscheduled.append(item)
                return
            }
            switch item.urgency {
            case .critical, .overdue:
                overdue.append(item)
            case .standard:
                if calendar.isDate(dueAt, inSameDayAs: startOfToday) {
                    today.append(item)
                } else {
                    upcoming.append(item)
                }
            }
        }
    }

    private struct EventItemProjection {
        var buckets = ItemBuckets()
        var representedFamilyTaskIDs: Set<UUID> = []
    }
}

nonisolated extension TaskCenterSnapshotBuilder {
    static func make(
        events: [Event],
        allEvents: [Event],
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        insurances: [PetInsurance] = [],
        petMedications: [PetMedication] = [],
        humanMedications: [HumanMedication] = [],
        reminders: [Reminder] = [],
        familyTasks: [FamilyCollaborationTask] = [],
        systemDestinations: Set<TaskCenterSystemDestination> = [],
        starterJourney: HouseholdStarterJourneySnapshot? = nil,
        activeHumanId: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskCenterSnapshot {
        let timeline = CalendarSnapshotBuilder.buildTimeline(
            events: events,
            allEvents: allEvents,
            pets: pets,
            now: now,
            calendar: calendar
        )
        let today = calendar.startOfDay(for: now)
        let recurringCutoff = calendar.date(
            byAdding: .day,
            value: -recurringOverdueLookbackDays,
            to: today
        ) ?? today
        let allKnownEvents = uniqueEvents(events + allEvents)
        let allKnownReminders = uniqueReminders(reminders + allKnownEvents.flatMap(\.reminders))
        let remindersByID = Dictionary(uniqueKeysWithValues: allKnownReminders.map { ($0.id, $0) })
        let eventsByID = Dictionary(uniqueKeysWithValues: allKnownEvents.map { ($0.id, $0) })
        let visibleFamilyTasks = familyTasks.filter { !$0.isFinished || $0.status == .declined }
        let familyTasksByEventID = Dictionary(grouping: visibleFamilyTasks.compactMap { task -> (UUID, FamilyCollaborationTask)? in
            guard let eventID = linkedEventID(for: task, remindersByID: remindersByID) else { return nil }
            return (eventID, task)
        }, by: \.0).mapValues { $0.map(\.1) }
        let context = ItemBuildContext(
            pets: pets,
            humans: humans,
            plants: plants,
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications,
            reminders: allKnownReminders,
            remindersByID: remindersByID,
            eventsByID: eventsByID,
            activeHumanId: activeHumanId,
            now: now,
            calendar: calendar
        )
        var pendingState = pendingEventState(
            occurrences: timeline.expandedOccurrences,
            today: today,
            recurringCutoff: recurringCutoff,
            calendar: calendar
        )
        var projection = eventItemProjection(
            pendingState.occurrencesByEventID,
            familyTasksByEventID: familyTasksByEventID,
            context: context
        )
        appendStandaloneFamilyTasks(
            visibleFamilyTasks,
            excluding: projection.representedFamilyTaskIDs,
            today: today,
            context: context,
            buckets: &projection.buckets
        )
        let visibleSystemItems = TaskCenterSystemJourneyProjection.makeVisibleItems(
            destinations: systemDestinations,
            starterJourney: starterJourney,
            pets: pets,
            humans: humans,
            now: now
        )
        for item in visibleSystemItems {
            projection.buckets.append(item, dueAt: nil, today: today, calendar: calendar)
        }
        applyFamilyTaskMetrics(
            familyTasks,
            today: today,
            context: context,
            state: &pendingState
        )
        let memberFilterContext = makeMemberFilterContext(
            items: projection.buckets.overdue
                + projection.buckets.today
                + projection.buckets.upcoming
                + projection.buckets.unscheduled,
            familyTasks: familyTasks,
            eventsByID: eventsByID,
            humans: humans,
            activeHumanId: activeHumanId
        )

        return TaskCenterSnapshot(
            overdue: projection.buckets.overdue.sorted(by: taskSort),
            today: projection.buckets.today.sorted(by: taskSort),
            upcoming: projection.buckets.upcoming.sorted(by: taskSort),
            unscheduled: projection.buckets.unscheduled.sorted(by: taskSort),
            todayCompletedCount: pendingState.completedTodayTaskKeys.count,
            todayTotalCount: pendingState.todayTaskKeys.count,
            memberFilterContext: memberFilterContext,
            starterJourney: starterJourney
        )
    }

    private static func pendingEventState(
        occurrences: [CalendarEventOccurrence],
        today: Date,
        recurringCutoff: Date,
        calendar: Calendar
    ) -> PendingEventState {
        var state = PendingEventState()
        for occurrence in occurrences {
            let event = occurrence.event
            guard event.isActionableTask else { continue }
            let occurrenceDay = calendar.startOfDay(for: occurrence.occurrenceDate)

            if occurrenceDay == today {
                let metricKey = eventOccurrenceID(eventID: event.id, date: occurrence.occurrenceDate)
                state.todayTaskKeys.insert(metricKey)
                if event.isOccurrenceMarkedComplete(on: occurrence.occurrenceDate) {
                    state.completedTodayTaskKeys.insert(metricKey)
                }
            }

            guard !event.isOccurrenceMarkedComplete(on: occurrence.occurrenceDate) else { continue }
            if event.recurrenceDays > 0, occurrenceDay < recurringCutoff {
                continue
            }
            state.occurrencesByEventID[event.id, default: []].append(occurrence)
        }
        return state
    }

    private static func eventItemProjection(
        _ occurrencesByEventID: [UUID: [CalendarEventOccurrence]],
        familyTasksByEventID: [UUID: [FamilyCollaborationTask]],
        context: ItemBuildContext
    ) -> EventItemProjection {
        var projection = EventItemProjection()
        for occurrences in occurrencesByEventID.values {
            guard let occurrence = currentOccurrence(
                from: occurrences,
                now: context.now,
                calendar: context.calendar
            ) else { continue }
            let familyTask = matchingFamilyTask(
                for: occurrence,
                candidates: familyTasksByEventID[occurrence.event.id] ?? [],
                calendar: context.calendar
            )
            let item = makeItem(
                occurrence: occurrence,
                familyTask: familyTask,
                context: context
            )
            if let familyTaskID = item.familyTaskID {
                projection.representedFamilyTaskIDs.insert(familyTaskID)
            }
            projection.buckets.append(
                item,
                dueAt: item.dueAt,
                today: context.calendar.startOfDay(for: context.now),
                calendar: context.calendar
            )
        }
        return projection
    }

    private static func appendStandaloneFamilyTasks(
        _ tasks: [FamilyCollaborationTask],
        excluding representedFamilyTaskIDs: Set<UUID>,
        today: Date,
        context: ItemBuildContext,
        buckets: inout ItemBuckets
    ) {
        for task in tasks where !representedFamilyTaskIDs.contains(task.id) {
            let reminder = linkedReminder(for: task, remindersByID: context.remindersByID)
            let event = linkedEvent(
                for: task,
                eventsByID: context.eventsByID,
                remindersByID: context.remindersByID
            )
            let dueAt = taskDueAt(task, event: event)
            let item = makeFamilyTaskItem(
                task: task,
                event: event,
                reminder: reminder,
                dueAt: dueAt,
                context: context
            )
            buckets.append(item, dueAt: dueAt, today: today, calendar: context.calendar)
        }
    }

    private static func applyFamilyTaskMetrics(
        _ tasks: [FamilyCollaborationTask],
        today: Date,
        context: ItemBuildContext,
        state: inout PendingEventState
    ) {
        for task in tasks where task.status != .cancelled {
            let event = linkedEvent(
                for: task,
                eventsByID: context.eventsByID,
                remindersByID: context.remindersByID
            )
            guard let dueAt = taskDueAt(task, event: event),
                  context.calendar.isDate(dueAt, inSameDayAs: today) else { continue }
            let metricKey = event.map { eventOccurrenceID(eventID: $0.id, date: dueAt) }
                ?? "family-\(task.id.uuidString)"
            state.todayTaskKeys.insert(metricKey)
            if task.status == .completed {
                state.completedTodayTaskKeys.insert(metricKey)
            } else if !task.isFinished || task.status == .declined {
                state.completedTodayTaskKeys.remove(metricKey)
            }
        }
    }

    private static func currentOccurrence(
        from occurrences: [CalendarEventOccurrence],
        now: Date,
        calendar: Calendar
    ) -> CalendarEventOccurrence? {
        let sorted = occurrences.sorted { occurrenceMoment($0, calendar: calendar) < occurrenceMoment($1, calendar: calendar) }
        if let overdue = sorted.first(where: { $0.event.isOverdue(on: $0.occurrenceDate, now: now) }) {
            return overdue
        }
        if let today = sorted.first(where: {
            calendar.isDate($0.occurrenceDate, inSameDayAs: now)
        }) {
            return today
        }
        return sorted.first
    }

    private static func makeItem(
        occurrence: CalendarEventOccurrence,
        familyTask: FamilyCollaborationTask?,
        context: ItemBuildContext
    ) -> TaskCenterItemSnapshot {
        let event = occurrence.event
        let subject = subjectPresentation(
            for: event,
            pets: context.pets,
            humans: context.humans,
            plants: context.plants,
            insurances: context.insurances,
            petMedications: context.petMedications,
            humanMedications: context.humanMedications
        )
        let isOverdue = event.isOverdue(on: occurrence.occurrenceDate, now: context.now)
        let urgency: TaskCenterUrgency = if isOverdue, isHealthCritical(event) {
            .critical
        } else if isOverdue {
            .overdue
        } else {
            .standard
        }
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let reminder = familyTask.flatMap { task in
            task.relatedReminderId.flatMap(UUID.init(uuidString:)).flatMap { reminderID in
                context.reminders.first(where: { $0.id == reminderID })
            }
        } ?? reminder(
            for: event,
            occurrenceDate: occurrence.occurrenceDate,
            reminders: context.reminders,
            calendar: context.calendar
        )
        let scheduledAt = occurrenceMoment(occurrence, calendar: context.calendar)

        return TaskCenterItemSnapshot(
            id: eventOccurrenceID(eventID: event.id, date: occurrence.occurrenceDate),
            eventID: event.id,
            reminderID: reminder?.id,
            familyTaskID: familyTask?.id,
            source: familyTask == nil ? .event : .linked,
            title: title.isEmpty ? event.eventType : title,
            subject: subject,
            eventType: event.eventTypeEnum,
            symbol: event.silhouetteListSymbol,
            occurrenceDate: occurrence.occurrenceDate,
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            isAllDay: event.isAllDay,
            isRecurring: familyTask?.planId != nil || event.familyTaskPlanId != nil || event.recurrenceDays > 0,
            urgency: urgency,
            workflowStatus: familyTask.map(workflowStatus) ?? .scheduled,
            availableActions: availableActions(
                for: familyTask,
                activeHumanId: context.activeHumanId,
                humans: context.humans
            ),
            participantHumanIDs: participantHumanIDs(event: event, familyTask: familyTask),
            createdByMember: familyTask.flatMap {
                memberSnapshot(idRaw: $0.createdById, storedName: $0.createdByName, humans: context.humans)
            },
            assignedToMember: familyTask.flatMap {
                memberSnapshot(idRaw: $0.assignedToId, storedName: $0.assignedToName, humans: context.humans)
            } ?? memberSnapshot(idRaw: event.assigneeId, storedName: nil, humans: context.humans),
            claimedByMember: familyTask.flatMap {
                memberSnapshot(idRaw: $0.claimedById, storedName: $0.claimedByName, humans: context.humans)
            },
            completedByMember: familyTask.flatMap {
                memberSnapshot(idRaw: $0.completedById, storedName: $0.completedByName, humans: context.humans)
            },
            rewardCoconuts: max(0, familyTask?.rewardCoconuts ?? 0)
        )
    }

    private static func makeFamilyTaskItem(
        task: FamilyCollaborationTask,
        event: Event?,
        reminder: Reminder?,
        dueAt: Date?,
        context: ItemBuildContext
    ) -> TaskCenterItemSnapshot {
        let subject = event.map {
            subjectPresentation(
                for: $0,
                pets: context.pets,
                humans: context.humans,
                plants: context.plants,
                insurances: context.insurances,
                petMedications: context.petMedications,
                humanMedications: context.humanMedications
            )
        } ?? standaloneSubject(
            for: task,
            pets: context.pets,
            humans: context.humans,
            plants: context.plants
        )
        let scheduledAt = dueAt ?? task.createdAt
        let isOverdue = dueAt.map { $0 < context.now } ?? false
        let urgency: TaskCenterUrgency = if isOverdue, event.map(isHealthCritical) == true {
            .critical
        } else if isOverdue {
            .overdue
        } else {
            .standard
        }
        let normalizedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return TaskCenterItemSnapshot(
            id: "family-\(task.id.uuidString)",
            eventID: event?.id,
            reminderID: reminder?.id ?? task.relatedReminderId.flatMap(UUID.init(uuidString:)),
            familyTaskID: task.id,
            source: event == nil ? .familyTask : .linked,
            title: normalizedTitle.isEmpty ? event?.eventType ?? task.kindRaw : normalizedTitle,
            subject: subject,
            eventType: event?.eventTypeEnum,
            symbol: event?.silhouetteListSymbol ?? (task.kind == .bounty ? "gift.fill" : "checkmark.circle.fill"),
            occurrenceDate: scheduledAt,
            scheduledAt: scheduledAt,
            dueAt: dueAt,
            isAllDay: event?.isAllDay ?? false,
            isRecurring: task.planId != nil || event?.familyTaskPlanId != nil || (event.map { $0.recurrenceDays > 0 } ?? false),
            urgency: urgency,
            workflowStatus: workflowStatus(task),
            availableActions: availableActions(
                for: task,
                activeHumanId: context.activeHumanId,
                humans: context.humans
            ),
            participantHumanIDs: participantHumanIDs(event: event, familyTask: task),
            createdByMember: memberSnapshot(
                idRaw: task.createdById,
                storedName: task.createdByName,
                humans: context.humans
            ),
            assignedToMember: memberSnapshot(
                idRaw: task.assignedToId ?? event?.assigneeId,
                storedName: task.assignedToName,
                humans: context.humans
            ),
            claimedByMember: memberSnapshot(
                idRaw: task.claimedById,
                storedName: task.claimedByName,
                humans: context.humans
            ),
            completedByMember: memberSnapshot(
                idRaw: task.completedById,
                storedName: task.completedByName,
                humans: context.humans
            ),
            rewardCoconuts: max(0, task.rewardCoconuts)
        )
    }

    private static func subjectPresentation(
        for event: Event,
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        insurances: [PetInsurance],
        petMedications: [PetMedication],
        humanMedications: [HumanMedication]
    ) -> TaskSubjectSnapshot {
        if let pet = MemberLifecycleActiveScheduleResolver.petTarget(
            for: event,
            pets: pets,
            petMedications: petMedications,
            insurances: insurances,
            includePassedAway: false
        ) {
            return TaskSubjectSnapshot(kind: .pet, id: pet.id, name: pet.name, themeColorHex: pet.themeColorHex)
        }
        if let plantID = DomainEntityLinkRegistry.plantId(for: event),
           let plant = plants.first(where: { $0.id == plantID && !$0.isArchived }) {
            return TaskSubjectSnapshot(kind: .plant, id: plant.id, name: plant.name, themeColorHex: plant.themeColorHex)
        }
        if let human = MemberLifecycleActiveScheduleResolver.humanOwner(
            for: event,
            humans: humans,
            humanMedications: humanMedications,
            includePassedAway: false
        ) ?? MemberLifecycleActiveScheduleResolver.humanInvolved(
            in: event,
            humans: humans,
            humanMedications: humanMedications,
            includePassedAway: false
        ) ?? MemberLifecycleActiveScheduleResolver.humanAssignee(
            for: event,
            humans: humans,
            includePassedAway: false
        ) {
            return TaskSubjectSnapshot(kind: .human, id: human.id, name: human.name, themeColorHex: human.themeColorHex)
        }
        return .household
    }

    private static func standaloneSubject(
        for task: FamilyCollaborationTask,
        pets: [Pet],
        humans: [Human],
        plants: [Plant]
    ) -> TaskSubjectSnapshot {
        let subjectID = task.resolvedSubjectId.flatMap(UUID.init(uuidString:))
        switch task.subjectKind {
        case .household:
            return .household
        case .human:
            let human = subjectID.flatMap { id in
                humans.first { $0.id == id && !$0.hasPassedAway }
            }
            return TaskSubjectSnapshot(
                kind: .human,
                id: subjectID,
                name: human?.name,
                themeColorHex: human?.themeColorHex
            )
        case .pet:
            let pet = subjectID.flatMap { id in
                pets.first { $0.id == id && !$0.hasPassedAway }
            }
            return TaskSubjectSnapshot(
                kind: .pet,
                id: subjectID,
                name: pet?.name,
                themeColorHex: pet?.themeColorHex
            )
        case .plant:
            let plant = subjectID.flatMap { id in
                plants.first { $0.id == id && !$0.isArchived }
            }
            return TaskSubjectSnapshot(
                kind: .plant,
                id: subjectID,
                name: plant?.name,
                themeColorHex: plant?.themeColorHex
            )
        }
    }

    private static func memberSnapshot(
        idRaw: String?,
        storedName: String?,
        humans: [Human]
    ) -> TaskMemberSnapshot? {
        let id = idRaw.flatMap(UUID.init(uuidString:))
        let currentName = id.flatMap { memberID in
            humans.first(where: { $0.id == memberID })?.name
        }
        let name = [currentName, storedName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
        guard id != nil || !name.isEmpty else { return nil }
        return TaskMemberSnapshot(id: id, name: name)
    }

    private static func occurrenceMoment(
        _ occurrence: CalendarEventOccurrence,
        calendar _: Calendar
    ) -> Date {
        let event = occurrence.event
        if event.recurrenceDays > 0, !event.isAllDay {
            return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrence.occurrenceDate)
        }
        return event.isAllDay ? occurrence.occurrenceDate : event.startDate
    }

    private static func isHealthCritical(_ event: Event) -> Bool {
        switch event.eventTypeEnum {
        case .medication, .petMedication, .petMedicationDose:
            true
        default:
            false
        }
    }

    private static func workflowStatus(_ task: FamilyCollaborationTask) -> TaskCenterWorkflowStatus {
        switch task.status {
        case .active:
            .active
        case .claimed:
            .claimed
        case .declined:
            .declined
        case .pendingReview:
            .pendingReview
        case .completed:
            .completed
        case .cancelled:
            .cancelled
        }
    }

    private static func availableActions(
        for task: FamilyCollaborationTask?,
        activeHumanId: String?,
        humans: [Human]
    ) -> Set<TaskCenterAvailableAction> {
        guard let task else { return [.complete] }
        let activeHumans = humans.filter { !$0.hasPassedAway }
        guard let activeHumanId,
              activeHumans.contains(where: { $0.id.uuidString == activeHumanId }) else { return [] }
        let supportsCollaboration = activeHumans.count > 1

        if !supportsCollaboration {
            switch task.status {
            case .active, .claimed:
                return task.hasReward ? [] : [.complete]
            case .declined, .pendingReview, .completed, .cancelled:
                return []
            }
        }

        switch task.status {
        case .active:
            if task.assignedToId == activeHumanId {
                if task.hasReward {
                    return [.submitForReview]
                }
                return [.complete]
            }
            if task.isOpen {
                return [.claim]
            }
            return []
        case .claimed:
            guard task.claimedById == activeHumanId else { return [] }
            if task.hasReward {
                return [.submitForReview]
            }
            return [.complete]
        case .pendingReview:
            guard task.createdById == activeHumanId else { return [] }
            return [.approve, .reject]
        case .declined, .completed, .cancelled:
            return []
        }
    }

    private static func makeMemberFilterContext(
        items: [TaskCenterItemSnapshot],
        familyTasks: [FamilyCollaborationTask],
        eventsByID: [UUID: Event],
        humans: [Human],
        activeHumanId: String?
    ) -> TaskCenterMemberFilterContext {
        let allItemIDs = Set(items.map(\.id))
        let systemJourneyItemIDs = Set(items.lazy.filter { $0.source == .systemJourney }.map(\.id))
        let activeHumans = humans.filter { !$0.hasPassedAway }
        guard activeHumans.count > 1 else {
            return TaskCenterMemberFilterContext(
                activeHumanName: activeHumans.first?.name,
                showsFilters: false,
                actionRequiredItemIDs: [],
                waitingForFamilyItemIDs: [],
                systemJourneyItemIDs: systemJourneyItemIDs,
                allItemIDs: allItemIDs
            )
        }
        let selectedHuman = activeHumanId.flatMap { activeID in
            activeHumans.first { $0.id.uuidString == activeID }
        } ?? activeHumans.first
        guard let selectedHuman else {
            return TaskCenterMemberFilterContext(
                activeHumanName: nil,
                showsFilters: false,
                actionRequiredItemIDs: [],
                waitingForFamilyItemIDs: [],
                systemJourneyItemIDs: systemJourneyItemIDs,
                allItemIDs: allItemIDs
            )
        }

        var familyTasksByID: [UUID: FamilyCollaborationTask] = [:]
        for task in familyTasks {
            familyTasksByID[task.id] = task
        }
        var actionRequiredItemIDs: Set<String> = []
        var waitingForFamilyItemIDs: Set<String> = []

        for item in items where item.source != .systemJourney {
            switch memberQueue(
                for: item,
                familyTasksByID: familyTasksByID,
                eventsByID: eventsByID,
                selectedHumanID: selectedHuman.id.uuidString
            ) {
            case .actionRequired:
                actionRequiredItemIDs.insert(item.id)
            case .waitingForFamily:
                waitingForFamilyItemIDs.insert(item.id)
            case .allOnly:
                break
            }
        }

        return TaskCenterMemberFilterContext(
            activeHumanName: selectedHuman.name,
            showsFilters: true,
            actionRequiredItemIDs: actionRequiredItemIDs,
            waitingForFamilyItemIDs: waitingForFamilyItemIDs,
            systemJourneyItemIDs: systemJourneyItemIDs,
            allItemIDs: allItemIDs
        )
    }

    private enum MemberQueue {
        case actionRequired
        case waitingForFamily
        case allOnly
    }

    private static func memberQueue(
        for item: TaskCenterItemSnapshot,
        familyTasksByID: [UUID: FamilyCollaborationTask],
        eventsByID: [UUID: Event],
        selectedHumanID: String
    ) -> MemberQueue {
        if let familyTaskID = item.familyTaskID,
           let task = familyTasksByID[familyTaskID] {
            return memberQueue(for: task, selectedHumanID: selectedHumanID)
        }
        if let eventID = item.eventID,
           eventsByID[eventID]?.assigneeId == selectedHumanID {
            return .actionRequired
        }
        return .allOnly
    }

    private static func memberQueue(
        for task: FamilyCollaborationTask,
        selectedHumanID: String
    ) -> MemberQueue {
        let isCreator = task.createdById == selectedHumanID
        let isAssignee = task.assignedToId == selectedHumanID
        let isClaimant = task.claimedById == selectedHumanID
        let isCompleter = task.completedById == selectedHumanID
        let isResponsible = (task.claimedById ?? task.assignedToId) == selectedHumanID

        switch task.status {
        case .active:
            if task.isOpen || isResponsible {
                return .actionRequired
            }
            return isCreator ? .waitingForFamily : .allOnly
        case .claimed:
            if isResponsible {
                return .actionRequired
            }
            return isCreator ? .waitingForFamily : .allOnly
        case .pendingReview:
            if isCreator {
                return .actionRequired
            }
            return isAssignee || isClaimant || isCompleter ? .waitingForFamily : .allOnly
        case .declined:
            if isCreator {
                return .actionRequired
            }
            return isAssignee || isClaimant ? .waitingForFamily : .allOnly
        case .completed, .cancelled:
            return .allOnly
        }
    }

    private static func participantHumanIDs(
        event: Event?,
        familyTask: FamilyCollaborationTask?
    ) -> Set<UUID> {
        let rawIDs = [
            event?.assigneeId,
            familyTask?.createdById,
            familyTask?.assignedToId,
            familyTask?.claimedById,
            familyTask?.completedById
        ]
        return Set(rawIDs.compactMap { rawID in
            guard let rawID else { return nil }
            return UUID(uuidString: rawID)
        })
    }

    private static func uniqueEvents(_ events: [Event]) -> [Event] {
        var result: [UUID: Event] = [:]
        for event in events {
            result[event.id] = event
        }
        return Array(result.values)
    }

    private static func uniqueReminders(_ reminders: [Reminder]) -> [Reminder] {
        var result: [UUID: Reminder] = [:]
        for reminder in reminders {
            result[reminder.id] = reminder
        }
        return Array(result.values)
    }

    private static func linkedReminder(
        for task: FamilyCollaborationTask,
        remindersByID: [UUID: Reminder]
    ) -> Reminder? {
        guard let rawID = task.relatedReminderId,
              let reminderID = UUID(uuidString: rawID) else { return nil }
        return remindersByID[reminderID]
    }

    private static func linkedEventID(
        for task: FamilyCollaborationTask,
        remindersByID: [UUID: Reminder]
    ) -> UUID? {
        if let rawID = task.relatedEventId,
           let eventID = UUID(uuidString: rawID) {
            return eventID
        }
        return linkedReminder(for: task, remindersByID: remindersByID)?.event?.id
    }

    private static func linkedEvent(
        for task: FamilyCollaborationTask,
        eventsByID: [UUID: Event],
        remindersByID: [UUID: Reminder]
    ) -> Event? {
        guard let eventID = linkedEventID(for: task, remindersByID: remindersByID) else { return nil }
        return eventsByID[eventID] ?? linkedReminder(for: task, remindersByID: remindersByID)?.event
    }

    private static func taskDueAt(
        _ task: FamilyCollaborationTask,
        event: Event?
    ) -> Date? {
        task.dueAt ?? event?.startDate
    }

    private static func matchingFamilyTask(
        for occurrence: CalendarEventOccurrence,
        candidates: [FamilyCollaborationTask],
        calendar: Calendar
    ) -> FamilyCollaborationTask? {
        let sorted = candidates.sorted {
            let lhsDate = taskDueAt($0, event: occurrence.event)
                ?? $0.createdAt
            let rhsDate = taskDueAt($1, event: occurrence.event)
                ?? $1.createdAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        if let exact = sorted.first(where: { task in
            guard let dueAt = taskDueAt(
                task,
                event: occurrence.event
            ) else { return false }
            return calendar.isDate(dueAt, inSameDayAs: occurrence.occurrenceDate)
        }) {
            return exact
        }
        return sorted.count == 1 ? sorted[0] : nil
    }

    private static func reminder(
        for event: Event,
        occurrenceDate: Date,
        reminders: [Reminder],
        calendar: Calendar
    ) -> Reminder? {
        reminders.first { reminder in
            reminder.event?.id == event.id &&
                calendar.isDate(reminder.resolvedOccurrenceAt, inSameDayAs: occurrenceDate)
        }
    }

    private static func eventOccurrenceID(eventID: UUID, date: Date) -> String {
        "\(eventID.uuidString)-\(CalendarSnapshotBuilder.timelineDateID(date))"
    }

    private static func taskSort(_ lhs: TaskCenterItemSnapshot, _ rhs: TaskCenterItemSnapshot) -> Bool {
        if lhs.scheduledAt == rhs.scheduledAt {
            let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            return lhs.id < rhs.id
        }
        return lhs.scheduledAt < rhs.scheduledAt
    }
}
