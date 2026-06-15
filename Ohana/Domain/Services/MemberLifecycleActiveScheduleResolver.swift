//
//  MemberLifecycleActiveScheduleResolver.swift
//  Ohana
//
//  Single source of truth for member-scoped active calendar/reminder schedules.
//

import Foundation

nonisolated enum MemberLifecycleActiveScheduleResolver {
    static func petTarget(
        for event: Event,
        pets: [Pet],
        petMedications: [PetMedication] = [],
        insurances: [PetInsurance] = [],
        includePassedAway: Bool = true
    ) -> Pet? {
        let medicationCandidates = petMedicationCandidates(pets: pets, explicit: petMedications)
        let insuranceCandidates = insuranceCandidates(pets: pets, explicit: insurances)
        return pets.first { pet in
            (includePassedAway || !pet.hasPassedAway) && eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: medicationCandidates,
                insurances: insuranceCandidates
            )
        }
    }

    static func humanOwner(
        for event: Event,
        humans: [Human],
        humanMedications: [HumanMedication],
        includePassedAway: Bool = true
    ) -> Human? {
        humans.first { human in
            (includePassedAway || !human.hasPassedAway) && eventOwnedByHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: humanMedications
            )
        }
    }

    static func humanInvolved(
        in event: Event,
        humans: [Human],
        humanMedications: [HumanMedication],
        includePassedAway: Bool = true
    ) -> Human? {
        humans.first { human in
            (includePassedAway || !human.hasPassedAway) && eventBelongsToHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: humanMedications
            )
        }
    }

    static func eventTargetsDeceasedActiveSchedule(
        _ event: Event,
        pets: [Pet],
        humans: [Human],
        petMedications: [PetMedication] = [],
        humanMedications: [HumanMedication] = [],
        insurances: [PetInsurance] = [],
        now: Date = Date()
    ) -> Bool {
        guard isActiveSchedule(event, now: now) else { return false }
        let medicationCandidates = petMedicationCandidates(pets: pets, explicit: petMedications)
        let insuranceCandidates = insuranceCandidates(pets: pets, explicit: insurances)
        if pets.contains(where: { pet in
            pet.hasPassedAway && eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: medicationCandidates,
                insurances: insuranceCandidates
            )
        }) {
            return true
        }

        let humanMedicationCandidates = humanMedicationCandidates(humans: humans, explicit: humanMedications)
        return humans.contains { human in
            human.hasPassedAway && eventBelongsToHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: humanMedicationCandidates
            )
        }
    }

    static func reminderTargetsActiveMember(
        _ reminder: Reminder,
        activePets: [Pet],
        activeHumans: [Human],
        petMedications: [PetMedication] = [],
        humanMedications: [HumanMedication] = [],
        insurances: [PetInsurance] = []
    ) -> Bool {
        guard let event = reminder.event else { return true }
        let medicationCandidates = petMedicationCandidates(pets: activePets, explicit: petMedications)
        let insuranceCandidates = insuranceCandidates(pets: activePets, explicit: insurances)
        if isPetScopedEntityType(event.relatedEntityType) {
            return activePets.contains { pet in
                eventBelongsToPet(
                    event,
                    petId: pet.id.uuidString,
                    petMedications: medicationCandidates,
                    insurances: insuranceCandidates
                )
            }
        }

        let humanMedicationCandidates = humanMedicationCandidates(humans: activeHumans, explicit: humanMedications)
        if isHumanScopedEntityType(event.relatedEntityType) {
            return activeHumans.contains { human in
                eventBelongsToHuman(
                    event,
                    humanId: human.id.uuidString,
                    humanMedications: humanMedicationCandidates
                )
            }
        }

        if let assigneeId = event.assigneeId, !assigneeId.isEmpty {
            return activeHumans.contains { $0.id.uuidString == assigneeId }
        }
        return true
    }

    static func eventBelongsToPet(
        _ event: Event,
        petId: String,
        petMedications: [PetMedication] = [],
        insurances: [PetInsurance] = []
    ) -> Bool {
        let link = DomainEntityLink(rawType: event.relatedEntityType, rawId: event.relatedEntityId)
        let role = DomainEntityLinkRegistry.role(for: link)
        if role == .petFoodStock {
            return event.relatedEntityId == petId || event.relatedEntityId.hasPrefix("\(petId):")
        }
        if event.relatedEntityId == petId {
            return role == .directPet || role == .petAutoFeeder || role == .petWaterPlan
        }
        if role == .petInsurance {
            return insurances.first { $0.id.uuidString == event.relatedEntityId }?.pet?.id.uuidString == petId
        }
        if role == .petMedicationDose || role == .petMedicationPlan {
            return petMedications.first { $0.id.uuidString == event.relatedEntityId }?.pet?.id.uuidString == petId
        }
        return false
    }

    static func eventBelongsToHuman(
        _ event: Event,
        humanId: String,
        humanMedications: [HumanMedication] = []
    ) -> Bool {
        if eventAssignedToHuman(event, humanId: humanId) {
            return true
        }
        return eventOwnedByHuman(event, humanId: humanId, humanMedications: humanMedications)
    }

    static func eventAssignedToHuman(_ event: Event, humanId: String) -> Bool {
        event.assigneeId == humanId
    }

    static func eventHasNoHumanAssignee(_ event: Event) -> Bool {
        (event.assigneeId ?? "").isEmpty
    }

    static func eventOwnedByHuman(
        _ event: Event,
        humanId: String,
        humanMedications: [HumanMedication]
    ) -> Bool {
        let link = DomainEntityLink(rawType: event.relatedEntityType, rawId: event.relatedEntityId)
        let role = DomainEntityLinkRegistry.role(for: link)
        if event.relatedEntityId == humanId {
            return role == .directHuman || role == .humanNote
        }
        if role == .humanMedicationPlan {
            return humanMedications.first { $0.id.uuidString == event.relatedEntityId }?.humanId == humanId
        }
        return false
    }

    static func isActiveSchedule(_ event: Event, now: Date = Date()) -> Bool {
        guard !isMemorialInformationEvent(event) else { return false }
        if event.recurrenceDays > 0 {
            guard event.recurrenceEndDate.map({ $0 < now }) != true else {
                return event.reminders.contains { isFutureActionableReminder($0, now: now) }
            }
            return true
        }
        if event.reminders.contains(where: { isFutureActionableReminder($0, now: now) }) {
            return true
        }
        guard event.startDate >= now, !event.isCompleted else { return false }
        guard !event.reminders.isEmpty else { return true }
        return event.reminders.contains { !isTerminalReminder($0) }
    }

    static func retainedHistoryExists(in event: Event, cutoff: Date) -> Bool {
        event.startDate < cutoff
            || event.isCompleted
            || !event.completedOccurrences.isEmpty
            || event.reminders.contains { $0.scheduledAt < cutoff || isTerminalReminder($0) }
    }

    static func futureActionableReminders(in event: Event, cutoff: Date) -> [Reminder] {
        event.reminders.filter { isFutureActionableReminder($0, now: cutoff) }
    }

    static func isMemorialInformationEvent(_ event: Event) -> Bool {
        event.eventType == EventType.birthday.rawValue || event.eventType == EventType.anniversary.rawValue
    }

    private static func isPetScopedEntityType(_ raw: String) -> Bool {
        DomainEntityLinkRegistry.role(for: DomainEntityLink(rawType: raw, rawId: "")).isPetScoped
    }

    private static func isHumanScopedEntityType(_ raw: String) -> Bool {
        DomainEntityLinkRegistry.role(for: DomainEntityLink(rawType: raw, rawId: "")).isHumanScoped
    }

    private static func isFutureActionableReminder(_ reminder: Reminder, now: Date) -> Bool {
        reminder.scheduledAt >= now && !isTerminalReminder(reminder)
    }

    private static func isTerminalReminder(_ reminder: Reminder) -> Bool {
        reminder.statusEnum == .completed || reminder.statusEnum == .skipped
    }

    private static func petMedicationCandidates(pets: [Pet], explicit: [PetMedication]) -> [PetMedication] {
        explicit.isEmpty ? pets.flatMap(\.medications) : explicit
    }

    private static func humanMedicationCandidates(humans _: [Human], explicit: [HumanMedication]) -> [HumanMedication] {
        explicit
    }

    private static func insuranceCandidates(pets: [Pet], explicit: [PetInsurance]) -> [PetInsurance] {
        explicit.isEmpty ? pets.flatMap(\.insurances) : explicit
    }
}
