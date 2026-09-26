//
//  MemberLifecycleActiveScheduleResolver.swift
//  Ohana
//
//  Single source of truth for member-scoped active calendar/reminder schedules.
//

import Foundation
import SwiftData

@MainActor
struct MemberLifecycleActiveScheduleSnapshot {
    let activePets: [Pet]
    let activeHumans: [Human]
    let petMedications: [PetMedication]
    let humanMedications: [HumanMedication]
    let insurances: [PetInsurance]

    init(context: ModelContext) {
        activePets = Self.fetch(FetchDescriptor<Pet>(), context: context, name: "Pet")
            .filter { !$0.hasPassedAway }
        activeHumans = Self.fetch(FetchDescriptor<Human>(), context: context, name: "Human")
            .filter { !$0.hasPassedAway }
        petMedications = Self.fetch(FetchDescriptor<PetMedication>(), context: context, name: "PetMedication")
        humanMedications = Self.fetch(FetchDescriptor<HumanMedication>(), context: context, name: "HumanMedication")
        insurances = Self.fetch(FetchDescriptor<PetInsurance>(), context: context, name: "PetInsurance")
    }

    func includes(_ reminder: Reminder) -> Bool {
        MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(
            reminder,
            activePets: activePets,
            activeHumans: activeHumans,
            petMedications: petMedications,
            humanMedications: humanMedications,
            insurances: insurances
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Member lifecycle reminder filter failed to fetch \(name): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }
}

nonisolated enum MemberLifecycleActiveScheduleResolver {
    static func petTarget(
        for event: Event,
        pets: [Pet],
        petMedications: [PetMedication] = [],
        insurances: [PetInsurance] = [],
        includePassedAway: Bool = true
    ) -> Pet? {
        let resolution = subjectResolution(
            for: event,
            petMedications: petMedicationCandidates(pets: pets, explicit: petMedications),
            insurances: insuranceCandidates(pets: pets, explicit: insurances),
            pets: pets
        )
        guard case let .pet(petId) = resolution.owner else { return nil }
        return pets.first {
            $0.id == petId && (includePassedAway || !$0.hasPassedAway)
        }
    }

    static func humanOwner(
        for event: Event,
        humans: [Human],
        humanMedications: [HumanMedication],
        includePassedAway: Bool = true
    ) -> Human? {
        let resolution = subjectResolution(
            for: event,
            humanMedications: humanMedicationCandidates(humans: humans, explicit: humanMedications),
            humans: humans
        )
        guard case let .human(humanId) = resolution.owner else { return nil }
        return humans.first {
            $0.id == humanId && (includePassedAway || !$0.hasPassedAway)
        }
    }

    static func humanInvolved(
        in event: Event,
        humans: [Human],
        humanMedications: [HumanMedication],
        includePassedAway: Bool = true
    ) -> Human? {
        let resolution = subjectResolution(
            for: event,
            humanMedications: humanMedicationCandidates(humans: humans, explicit: humanMedications),
            humans: humans
        )
        return humans.first { human in
            (includePassedAway || !human.hasPassedAway) && resolution.lifecycleTargets.contains(.human(human.id))
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
        let resolution = subjectResolution(
            for: event,
            petMedications: petMedicationCandidates(pets: pets, explicit: petMedications),
            humanMedications: humanMedicationCandidates(humans: humans, explicit: humanMedications),
            insurances: insuranceCandidates(pets: pets, explicit: insurances),
            pets: pets,
            humans: humans
        )
        if pets.contains(where: { $0.hasPassedAway && resolution.lifecycleTargets.contains(.pet($0.id)) }) {
            return true
        }

        return humans.contains { human in
            human.hasPassedAway && resolution.lifecycleTargets.contains(.human(human.id))
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
        let resolution = subjectResolution(
            for: event,
            petMedications: petMedicationCandidates(pets: activePets, explicit: petMedications),
            humanMedications: humanMedicationCandidates(humans: activeHumans, explicit: humanMedications),
            insurances: insuranceCandidates(pets: activePets, explicit: insurances),
            pets: activePets,
            humans: activeHumans
        )
        if resolution.role.isPetScoped {
            guard case let .pet(petId) = resolution.owner else { return false }
            return activePets.contains { $0.id == petId }
        }

        if resolution.role.isHumanScoped {
            return activeHumans.contains { human in
                resolution.lifecycleTargets.contains(.human(human.id))
            }
        }

        if let assignee = resolution.assignee {
            return activeHumans.contains { human in
                assignee == .human(human.id)
            }
        }
        return true
    }

    static func eventBelongsToPet(
        _ event: Event,
        petId: String,
        petMedications: [PetMedication] = [],
        insurances: [PetInsurance] = []
    ) -> Bool {
        guard let id = UUID(uuidString: petId) else { return false }
        return subjectResolution(
            for: event,
            petMedications: petMedications,
            insurances: insurances
        ).owner == .pet(id)
    }

    static func eventBelongsToHuman(
        _ event: Event,
        humanId: String,
        humanMedications: [HumanMedication] = []
    ) -> Bool {
        guard let id = UUID(uuidString: humanId) else { return false }
        return subjectResolution(
            for: event,
            humanMedications: humanMedications
        ).lifecycleTargets.contains(.human(id))
    }

    static func eventAssignedToHuman(_ event: Event, humanId: String) -> Bool {
        guard let id = UUID(uuidString: humanId) else { return false }
        return subjectResolution(for: event).assignee == .human(id)
    }

    static func humanAssignee(
        for event: Event,
        humans: [Human],
        includePassedAway: Bool = true
    ) -> Human? {
        guard case let .human(humanId) = subjectResolution(for: event, humans: humans).assignee else { return nil }
        return humans.first {
            $0.id == humanId && (includePassedAway || !$0.hasPassedAway)
        }
    }

    static func eventHasNoHumanAssignee(_ event: Event) -> Bool {
        subjectResolution(for: event).assignee == nil
    }

    static func eventOwnedByHuman(
        _ event: Event,
        humanId: String,
        humanMedications: [HumanMedication]
    ) -> Bool {
        guard let id = UUID(uuidString: humanId) else { return false }
        return subjectResolution(
            for: event,
            humanMedications: humanMedications
        ).owner == .human(id)
    }

    static func isActiveSchedule(_ event: Event, now: Date = Date()) -> Bool {
        guard !isMemorialInformationEvent(event) else { return false }
        if event.recurrenceDays > 0 {
            guard event.recurrenceEndDate.map({ $0 <= now }) != true else {
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

    private static func subjectResolution(
        for event: Event,
        petMedications: [PetMedication] = [],
        humanMedications: [HumanMedication] = [],
        insurances: [PetInsurance] = [],
        pets: [Pet] = [],
        humans: [Human] = []
    ) -> DomainSubjectResolution {
        DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            catalog: DomainSubjectResolutionCatalog(
                pets: pets,
                petMedications: petMedications,
                humanMedications: humanMedications,
                insurances: insurances,
                humans: humans
            )
        )
    }
}
