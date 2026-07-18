//
//  TaskCenterRouteDataActor.swift
//  Ohana
//
//  Bounded SwiftData loading and main-context rehydration for Task Center.
//

import Foundation
import SwiftData

nonisolated struct TaskCenterRouteDataReference: Sendable {
    let snapshot: TaskCenterSnapshot
    let eventModelIDs: [PersistentIdentifier]
    let reminderModelIDs: [PersistentIdentifier]
    let familyTaskModelIDs: [PersistentIdentifier]
    let petModelIDs: [PersistentIdentifier]
    let humanModelIDs: [PersistentIdentifier]
    let plantModelIDs: [PersistentIdentifier]
    let humanMedicationModelIDs: [PersistentIdentifier]
}

struct TaskCenterRouteData {
    var snapshot = TaskCenterSnapshot.empty
    var events: [Event] = []
    var reminders: [Reminder] = []
    var familyTasks: [FamilyCollaborationTask] = []
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var humanMedications: [HumanMedication] = []
    var hasLoaded = false

    init() {}

    @MainActor
    init(reference: TaskCenterRouteDataReference, context: ModelContext) {
        snapshot = reference.snapshot
        events = Self.rehydrate(reference.eventModelIDs, as: Event.self, context: context)
        reminders = Self.rehydrate(reference.reminderModelIDs, as: Reminder.self, context: context)
        familyTasks = Self.rehydrate(
            reference.familyTaskModelIDs,
            as: FamilyCollaborationTask.self,
            context: context
        )
        pets = Self.rehydrate(reference.petModelIDs, as: Pet.self, context: context)
        humans = Self.rehydrate(reference.humanModelIDs, as: Human.self, context: context)
        plants = Self.rehydrate(reference.plantModelIDs, as: Plant.self, context: context)
        humanMedications = Self.rehydrate(
            reference.humanMedicationModelIDs,
            as: HumanMedication.self,
            context: context
        )
        hasLoaded = true
    }

    @MainActor
    private static func rehydrate<T: PersistentModel>(
        _ identifiers: [PersistentIdentifier],
        as _: T.Type,
        context: ModelContext
    ) -> [T] {
        identifiers.compactMap { context.model(for: $0) as? T }
    }
}

@ModelActor
actor TaskCenterRouteDataActor {
    private static let completedFamilyTaskFetchLimit = 300

    func load(
        loadPlants: Bool,
        activeHumanID: String?,
        systemDestinations: Set<TaskCenterSystemDestination> = [],
        starterJourneyEnabled: Bool = false,
        now: Date = Date()
    ) throws -> TaskCenterRouteDataReference {
        try Task.checkCancellation()
        let pets = fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]), name: "Pet")
        let humans = fetch(FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]), name: "Human")
        let plants = loadPlants
            ? fetch(FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]), name: "Plant")
            : []
        let insurances = fetch(
            FetchDescriptor<PetInsurance>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "PetInsurance"
        )
        let petMedications = fetch(
            FetchDescriptor<PetMedication>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "PetMedication"
        )
        let humanMedications = fetch(
            FetchDescriptor<HumanMedication>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "HumanMedication"
        )
        let allEvents = fetchVisibleEvents(now: now)
        let allReminders = fetchVisibleReminders()
        let allActiveFamilyTasks = fetchActiveFamilyTasks()
        let completedFamilyTasks = fetchCompletedFamilyTasks(on: now)
        let starterJourney = buildStarterJourneySnapshot(
            enabled: starterJourneyEnabled,
            activeHumanID: activeHumanID,
            pets: pets,
            humans: humans
        )
        let events = allEvents.filter { event in
            if !loadPlants, DomainEntityLinkRegistry.plantId(for: event) != nil {
                return false
            }
            return !MemberLifecycleActiveScheduleResolver.eventTargetsDeceasedActiveSchedule(
                event,
                pets: pets,
                humans: humans,
                petMedications: petMedications,
                humanMedications: humanMedications,
                insurances: insurances,
                now: now
            )
        }
        let activePets = pets.filter { !$0.hasPassedAway }
        let activeHumans = humans.filter { !$0.hasPassedAway }
        let reminders = allReminders.filter {
            MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(
                $0,
                activePets: activePets,
                activeHumans: activeHumans,
                petMedications: petMedications,
                humanMedications: humanMedications,
                insurances: insurances
            )
        }
        let excludedEventIDs = Set(allEvents.map(\.id)).subtracting(events.map(\.id))
        let excludedReminderIDs = Set(allReminders.map(\.id)).subtracting(reminders.map(\.id))
        let activePetIDs = Set(activePets.map(\.id.uuidString))
        let activeHumanIDs = Set(activeHumans.map(\.id.uuidString))
        let knownHumanIDs = Set(humans.map(\.id.uuidString))
        let activeFamilyTasks = allActiveFamilyTasks.filter {
            activeFamilyTaskTargetsActiveMember(
                $0,
                activePetIDs: activePetIDs,
                activeHumanIDs: activeHumanIDs,
                knownHumanIDs: knownHumanIDs,
                excludedEventIDs: excludedEventIDs,
                excludedReminderIDs: excludedReminderIDs
            )
        }
        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: pets,
            humans: humans,
            plants: plants,
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications,
            reminders: reminders,
            familyTasks: activeFamilyTasks + completedFamilyTasks,
            systemDestinations: systemDestinations,
            starterJourney: starterJourney,
            activeHumanId: activeHumanID,
            now: now
        )
        try Task.checkCancellation()

        return TaskCenterRouteDataReference(
            snapshot: snapshot,
            eventModelIDs: events.map(\.persistentModelID),
            reminderModelIDs: reminders.map(\.persistentModelID),
            familyTaskModelIDs: activeFamilyTasks.map(\.persistentModelID),
            petModelIDs: pets.map(\.persistentModelID),
            humanModelIDs: humans.map(\.persistentModelID),
            plantModelIDs: plants.map(\.persistentModelID),
            humanMedicationModelIDs: humanMedications.map(\.persistentModelID)
        )
    }

    private func buildStarterJourneySnapshot(
        enabled: Bool,
        activeHumanID: String?,
        pets: [Pet],
        humans: [Human]
    ) -> HouseholdStarterJourneySnapshot {
        let targetPet = enabled
            ? pets.filter { !$0.hasPassedAway }.sorted(by: starterJourneyPetWasCreatedEarlier).first
            : nil
        let carePlanEvents = fetchStarterJourneyCarePlanEvents(targetPet: targetPet)
        let carePlanReminderEventIDs = fetchStarterJourneyCarePlanReminderEventIDs(
            targetPet: targetPet,
            candidateEvents: carePlanEvents
        )
        let careLedgerEvents = enabled
            ? fetchStarterJourneyCareLedgerEvents(
                targetPetID: targetPet?.id,
                humanTargetIDs: starterJourneyHumanTargetIDs(
                    activeHumanID: activeHumanID,
                    humans: humans
                )
            )
            : []
        let coconutLedgerEntries = enabled
            ? fetchStarterJourneyCoconutLedgerEntries()
            : []
        let qualificationFacts = starterJourneyQualificationFacts(
            targetPet: targetPet,
            carePlanEvents: carePlanEvents,
            carePlanReminderEventIDs: carePlanReminderEventIDs
        )
        return HouseholdStarterJourneyService.buildSnapshot(
            enabled: enabled,
            activeHumanID: activeHumanID,
            humans: humans,
            pets: pets,
            qualificationFacts: qualificationFacts,
            careLedgerEvents: careLedgerEvents,
            coconutLedgerEntries: coconutLedgerEntries
        )
    }

    private func fetchStarterJourneyCareLedgerEvents(
        targetPetID: UUID?,
        humanTargetIDs: [UUID]
    ) -> [CareLedgerEvent] {
        let checkpointAction = HouseholdStarterJourneyService.checkpointActionType
        let checkpointModelName = HouseholdStarterJourneyService.checkpointSourceModelName
        let rewardAction = HouseholdStarterJourneyService.rewardActionType
        let rewardModelName = HouseholdStarterJourneyService.rewardSourceModelName
        var values: [CareLedgerEvent] = []

        for humanID in humanTargetIDs {
            for checkpoint in HouseholdStarterJourneyTask.humanProfile.checkpoints {
                let recordKey = HouseholdStarterJourneyService.checkpointRecordKey(
                    task: checkpoint.task,
                    checkpoint: checkpoint,
                    subjectID: humanID
                )
                if let marker = fetchLatestStarterJourneyMarker(
                    actionType: checkpointAction,
                    modelName: checkpointModelName,
                    modelID: recordKey,
                    name: "CareLedgerEvent.starterJourneyHumanCheckpoint"
                ) {
                    values.append(marker)
                }
            }
        }

        if let targetPetID {
            for checkpoint in HouseholdStarterJourneyCheckpoint.allCases
                where checkpoint.targetKind == .pet {
                let recordKey = HouseholdStarterJourneyService.checkpointRecordKey(
                    task: checkpoint.task,
                    checkpoint: checkpoint,
                    subjectID: targetPetID
                )
                if let marker = fetchLatestStarterJourneyMarker(
                    actionType: checkpointAction,
                    modelName: checkpointModelName,
                    modelID: recordKey,
                    name: "CareLedgerEvent.starterJourneyPetCheckpoint"
                ) {
                    values.append(marker)
                }
            }
        }

        for task in HouseholdStarterJourneyTask.allCases {
            if let marker = fetchLatestStarterJourneyMarker(
                actionType: rewardAction,
                modelName: rewardModelName,
                modelID: task.id,
                name: "CareLedgerEvent.starterJourneyReward"
            ) {
                values.append(marker)
            }
        }

        if let targetPetID {
            let targetPetID = targetPetID.uuidString
            let careKind = CareLedgerEventKind.care.rawValue
            let pottyKind = CareLedgerEventKind.potty.rawValue
            let walkKind = CareLedgerEventKind.walk.rawValue
            let hygieneKind = CareLedgerEventKind.hygiene.rawValue
            var careDescriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectId == targetPetID &&
                        (event.eventKind == careKind ||
                            event.eventKind == pottyKind ||
                            event.eventKind == walkKind ||
                            event.eventKind == hygieneKind)
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
            careDescriptor.fetchLimit = 16
            values.append(contentsOf: fetch(careDescriptor, name: "CareLedgerEvent.starterJourneyCare"))
        }

        var seen: Set<UUID> = []
        return values.filter { seen.insert($0.id).inserted }
    }

    private func fetchLatestStarterJourneyMarker(
        actionType: String,
        modelName: String,
        modelID: String,
        name: String
    ) -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType == actionType
                    && event.legacyModelName == modelName
                    && event.legacyModelId == modelID
            },
            sortBy: [
                SortDescriptor(\.occurredAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 1
        return fetch(descriptor, name: name).first
    }

    private func starterJourneyHumanTargetIDs(
        activeHumanID: String?,
        humans: [Human]
    ) -> [UUID] {
        let livingHumans = humans
            .filter { $0.passedAwayDate == nil }
            .sorted(by: starterJourneyHumanWasCreatedEarlier)
        if let activeHumanID,
           let requestedID = UUID(uuidString: activeHumanID),
           livingHumans.contains(where: { $0.id == requestedID }) {
            return [requestedID]
        }
        return livingHumans.map(\.id)
    }

    private func fetchStarterJourneyCoconutLedgerEntries() -> [CoconutLedgerEntry] {
        let sourceModelName = HouseholdStarterJourneyService.rewardSourceModelName
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { entry in
                entry.sourceModelName == sourceModelName
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = HouseholdStarterJourneyTask.allCases.count
        return fetch(descriptor, name: "CoconutLedgerEntry.starterJourney")
    }

    private func starterJourneyQualificationFacts(
        targetPet: Pet?,
        carePlanEvents: [Event],
        carePlanReminderEventIDs: Set<UUID>
    ) -> HouseholdStarterJourneyQualificationFacts {
        guard let targetPet else { return .empty }
        let targetPetID = targetPet.id
        let carePlan = HouseholdStarterJourneyService.carePlanEvidence(
            targetPet: targetPet,
            events: carePlanEvents,
            reminderEventIDs: carePlanReminderEventIDs
        )
        return HouseholdStarterJourneyQualificationFacts(
            targetPetID: targetPetID,
            hasProtectionDocument: hasStarterJourneyProtectionDocument(petID: targetPetID),
            hasInsurance: hasStarterJourneyInsurance(petID: targetPetID),
            hasPreventiveHealthRecord: hasStarterJourneyPreventiveHealthRecord(petID: targetPetID),
            hasExplicitCarePlan: carePlan.hasExplicitCarePlan,
            hasDefaultRecommendedCarePlan: carePlan.hasDefaultRecommendedCarePlan
        )
    }

    private func hasStarterJourneyProtectionDocument(petID: UUID) -> Bool {
        let passport = DocumentCategory.passport.rawValue
        let medical = DocumentCategory.medical.rawValue
        let registration = DocumentCategory.registration.rawValue
        let other = DocumentCategory.other.rawValue
        var descriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> { document in
                document.pet?.id == petID
                    && (document.category == passport
                        || document.category == medical
                        || document.category == registration
                        || document.category == other)
            }
        )
        descriptor.fetchLimit = 1
        return !fetch(descriptor, name: "PetDocument.starterJourneyProtection").isEmpty
    }

    private func hasStarterJourneyInsurance(petID: UUID) -> Bool {
        var descriptor = FetchDescriptor<PetInsurance>(
            predicate: #Predicate<PetInsurance> { insurance in
                insurance.pet?.id == petID
            }
        )
        descriptor.fetchLimit = 1
        return !fetch(descriptor, name: "PetInsurance.starterJourney").isEmpty
    }

    private func hasStarterJourneyPreventiveHealthRecord(petID: UUID) -> Bool {
        let vaccine = HealthLogType.vaccine.rawValue
        let internalDeworming = HealthLogType.dewormingInternal.rawValue
        let externalDeworming = HealthLogType.dewormingExternal.rawValue
        let checkup = HealthLogType.checkup.rawValue
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { log in
                log.pet?.id == petID
                    && (log.type == vaccine
                        || log.type == internalDeworming
                        || log.type == externalDeworming
                        || log.type == checkup)
            }
        )
        descriptor.fetchLimit = 1
        return !fetch(descriptor, name: "PetHealthLog.starterJourneyPreventive").isEmpty
    }

    private func fetchStarterJourneyCarePlanEvents(targetPet: Pet?) -> [Event] {
        guard let targetPet else { return [] }
        let targetPetID = targetPet.id.uuidString
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == targetPetID
                    && event.recurrenceDays > 0
                    && !event.isCompleted
            },
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id)
            ]
        )
        descriptor.fetchLimit = 64
        var events = fetch(descriptor, name: "Event.starterJourneyCarePlan")
        if let explicitEvent = fetchStarterJourneyExplicitCarePlanEvent(targetPetID: targetPetID),
           !events.contains(where: { $0.id == explicitEvent.id }) {
            events.append(explicitEvent)
        }
        let storedEventIDs = CarePlanCalendarSync.storedDefaultCalendarPlanEventIDs(for: targetPet.id)
            + CarePlanCalendarSync.storedExplicitCalendarPlanEventIDs(for: targetPet.id)
        for eventID in storedEventIDs {
            var storedDescriptor = FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.id == eventID
                        && event.relatedEntityId == targetPetID
                        && event.recurrenceDays > 0
                        && !event.isCompleted
                }
            )
            storedDescriptor.fetchLimit = 1
            if let event = fetch(storedDescriptor, name: "Event.starterJourneyStoredCarePlan").first,
               !events.contains(where: { $0.id == event.id }) {
                events.append(event)
            }
        }
        for title in CarePlanCalendarSync.defaultGeneratedCalendarPlanTitles(for: targetPet).sorted() {
            var titleDescriptor = FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.relatedEntityId == targetPetID
                        && event.title == title
                        && event.recurrenceDays > 0
                        && !event.isCompleted
                },
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.id)
                ]
            )
            titleDescriptor.fetchLimit = 1
            if let event = fetch(titleDescriptor, name: "Event.starterJourneyLegacyDefaultCarePlan").first,
               !events.contains(where: { $0.id == event.id }) {
                events.append(event)
            }
        }
        return events
    }

    private func fetchStarterJourneyExplicitCarePlanEvent(targetPetID: String) -> Event? {
        for careKind in TaskCareKind.allCases where careKind.subjectKind == .pet {
            let careKindRaw = careKind.rawValue
            var descriptor = FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.relatedEntityId == targetPetID
                        && event.recurrenceDays > 0
                        && !event.isCompleted
                        && event.taskCareKindRaw == careKindRaw
                },
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.id)
                ]
            )
            descriptor.fetchLimit = 1
            if let event = fetch(descriptor, name: "Event.starterJourneyTypedCarePlan").first {
                return event
            }
        }

        var feedRuleDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == targetPetID
                    && event.recurrenceDays > 0
                    && !event.isCompleted
                    && event.feedRuleKindRaw != ""
            },
            sortBy: [
                SortDescriptor(\.createdAt),
                SortDescriptor(\.id)
            ]
        )
        feedRuleDescriptor.fetchLimit = 1
        if let event = fetch(feedRuleDescriptor, name: "Event.starterJourneyFeedRuleCarePlan").first {
            return event
        }

        for relatedEntityType in [
            DomainEntityLinkRegistry.petAutoFeeder,
            DomainEntityLinkRegistry.petWaterPlan
        ] {
            var descriptor = FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.relatedEntityId == targetPetID
                        && event.recurrenceDays > 0
                        && !event.isCompleted
                        && event.relatedEntityType == relatedEntityType
                },
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.id)
                ]
            )
            descriptor.fetchLimit = 1
            if let event = fetch(descriptor, name: "Event.starterJourneyLinkedCarePlan").first {
                return event
            }
        }
        return nil
    }

    private func fetchStarterJourneyCarePlanReminderEventIDs(
        targetPet: Pet?,
        candidateEvents: [Event]
    ) -> Set<UUID> {
        guard let targetPet else { return [] }
        let targetPetID = targetPet.id.uuidString
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.event?.relatedEntityId == targetPetID
            },
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id)
            ]
        )
        descriptor.fetchLimit = 128
        var reminderEventIDs = Set(
            fetch(descriptor, name: "Reminder.starterJourneyCarePlan").compactMap { $0.event?.id }
        )
        for event in candidateEvents
            where !reminderEventIDs.contains(event.id)
            && CarePlanCalendarSync.isDefaultGeneratedCalendarPlan(
                event,
                pets: [targetPet],
                hasReminder: false
            ) {
            let eventID = event.id
            var exactDescriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.event?.id == eventID
                }
            )
            exactDescriptor.fetchLimit = 1
            if !fetch(exactDescriptor, name: "Reminder.starterJourneyCarePlanExact").isEmpty {
                reminderEventIDs.insert(eventID)
            }
        }
        return reminderEventIDs
    }

    private func starterJourneyPetWasCreatedEarlier(_ lhs: Pet, _ rhs: Pet) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func starterJourneyHumanWasCreatedEarlier(_ lhs: Human, _ rhs: Human) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func fetchVisibleEvents(now: Date) -> [Event] {
        let calendar = Calendar.current
        let window = CalendarTimelineWindowPolicy.bounds(around: now, calendar: calendar)
        let windowStart = window.start
        let windowEnd = window.end
        var windowedDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.startDate >= windowStart && event.startDate <= windowEnd
            },
            sortBy: [
                SortDescriptor(\.startDate),
                SortDescriptor(\.id)
            ]
        )
        windowedDescriptor.fetchLimit = CalendarTimelineWindowPolicy.windowedEventFetchLimit
        let windowedEvents = fetch(windowedDescriptor, name: "Event.window")

        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= windowEnd
            },
            sortBy: [
                SortDescriptor(\.startDate, order: .reverse),
                SortDescriptor(\.id)
            ]
        )
        recurringDescriptor.fetchLimit = CalendarTimelineWindowPolicy.recurringEventFetchLimit
        let recurringEvents = fetch(recurringDescriptor, name: "Event.recurring").filter { event in
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return recurrenceEndDate >= windowStart
        }

        var uniqueEvents: [UUID: Event] = [:]
        for event in windowedEvents + recurringEvents {
            uniqueEvents[event.id] = event
        }
        return uniqueEvents.values.sorted { $0.startDate < $1.startDate }
    }

    private func fetchVisibleReminders() -> [Reminder] {
        let pendingStatus = "pending"
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus
            },
            sortBy: [SortDescriptor(\.scheduledAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 400
        return fetch(descriptor, name: "Reminder.pending")
    }

    private func activeFamilyTaskTargetsActiveMember(
        _ task: FamilyCollaborationTask,
        activePetIDs: Set<String>,
        activeHumanIDs: Set<String>,
        knownHumanIDs: Set<String>,
        excludedEventIDs: Set<UUID>,
        excludedReminderIDs: Set<UUID>
    ) -> Bool {
        if let assignedToID = task.assignedToId,
           knownHumanIDs.contains(assignedToID),
           !activeHumanIDs.contains(assignedToID) {
            return false
        }
        if let rawEventID = task.relatedEventId,
           let eventID = UUID(uuidString: rawEventID),
           excludedEventIDs.contains(eventID) {
            return false
        }
        if let rawReminderID = task.relatedReminderId,
           let reminderID = UUID(uuidString: rawReminderID),
           excludedReminderIDs.contains(reminderID) {
            return false
        }

        switch task.subjectKind {
        case .household, .plant:
            return true
        case .human:
            guard let subjectID = task.resolvedSubjectId else { return false }
            return activeHumanIDs.contains(subjectID)
        case .pet:
            guard let subjectID = task.resolvedSubjectId else { return false }
            return activePetIDs.contains(subjectID)
        }
    }

    private func fetchActiveFamilyTasks() -> [FamilyCollaborationTask] {
        let active = FamilyCollaborationTaskStatus.active.rawValue
        let claimed = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReview = FamilyCollaborationTaskStatus.pendingReview.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.statusRaw == active ||
                    task.statusRaw == claimed ||
                    task.statusRaw == pendingReview
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 300
        return fetch(descriptor, name: "FamilyCollaborationTask.active")
    }

    private func fetchCompletedFamilyTasks(on date: Date) -> [FamilyCollaborationTask] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let completed = FamilyCollaborationTaskStatus.completed.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.statusRaw == completed &&
                    task.updatedAt >= dayStart &&
                    task.updatedAt < dayEnd
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = Self.completedFamilyTaskFetchLimit
        return fetch(descriptor, name: "FamilyCollaborationTask.completedToday").filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= dayStart && completedAt < dayEnd
        }
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        name: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Task center data fetch failed for \(name): \(error.localizedDescription)",
                category: "Tasks"
            )
            return []
        }
    }
}
