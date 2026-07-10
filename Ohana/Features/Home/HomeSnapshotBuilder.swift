//
//  HomeSnapshotBuilder.swift
//  Ohana
//
//  Pure home card snapshot aggregation.
//

import Foundation

nonisolated enum HomeSnapshotBuilder {
    static func buildCards(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        events: [Event],
        statusReminders: [Reminder]? = nil,
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        careLedgerEntries: [HomeCareQuickActionEntry]? = nil,
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        now: Date = Date(),
        l: L10n = .current
    ) -> [FocusCard] {
        let medicationLogs = recentHumanMedicationLogs(from: humanMedicationLogs, now: now)
        let eventIndex = HomeCarePlanEventIndex(
            pets: pets,
            humans: humans,
            events: events,
            statusReminders: statusReminders,
            humanMedications: humanMedications
        )
        return FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            l: l
        )
        .map {
            decoratedStatusCard(
                $0,
                pets: pets,
                humans: humans,
                eventIndex: eventIndex,
                humanMedications: humanMedications,
                humanMedicationLogs: medicationLogs,
                careLedgerEntries: careLedgerEntries,
                now: now,
                l: l
            )
        }
    }

    static func actionableOverdueEvents(from events: [Event], now: Date = Date()) -> [Event] {
        events.filter { event in
            guard event.isActionableTask else { return false }
            return event.reminders.contains { reminder in
                reminder.isFailed || (reminder.isPending && reminder.scheduledAt < now)
            }
        }
    }

    static func recentHumanMedicationLogs(
        from logs: [HumanMedicationLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [HumanMedicationLog] {
        let cutoff = calendar.date(byAdding: .day, value: -8, to: now) ?? .distantPast
        return logs.filter { $0.scheduledTime >= cutoff }
    }

    private static func decoratedStatusCard(
        _ card: FocusCard,
        pets: [Pet],
        humans: [Human],
        eventIndex: HomeCarePlanEventIndex,
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        careLedgerEntries: [HomeCareQuickActionEntry]? = nil,
        now: Date = Date(),
        l _: L10n = .current
    ) -> FocusCard {
        guard !card.isElectronicPet else {
            return card
        }

        let urgentCount: Int
        let dueCount: Int
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            let events = eventIndex.statusEvents(for: .human(human.id))
            urgentCount = CarePlanOverdueStatusCalculator.humanWarningCount(
                for: human,
                events: events,
                medications: humanMedications,
                logs: humanMedicationLogs,
                now: now
            )
            dueCount = CarePlanOverdueStatusCalculator.humanDueTodayCount(
                human: human,
                events: events,
                medications: humanMedications,
                logs: humanMedicationLogs,
                now: now
            )
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            let events = eventIndex.statusEvents(for: .pet(pet.id))
            let feedRuleEvents = eventIndex.feedRuleEvents(for: pet.id)
            let waterCycleSnapshot = careLedgerEntries.map { waterCycleLogSnapshot(for: pet, careLedgerEntries: $0) }
            urgentCount = CarePlanOverdueStatusCalculator.petWarningCount(
                for: pet,
                events: events,
                feedRuleEvents: feedRuleEvents,
                now: now,
                waterCycleLogSnapshot: waterCycleSnapshot
            )
            dueCount = CarePlanOverdueStatusCalculator.petDueTodayCount(
                pet: pet,
                events: events,
                feedRuleEvents: feedRuleEvents,
                now: now,
                waterCycleLogSnapshot: waterCycleSnapshot
            )
        } else {
            urgentCount = 0
            dueCount = 0
        }

        var copy = card
        HomeCardStatusPolicy.apply(to: &copy, urgentCount: urgentCount, dueCount: dueCount)
        return copy
    }

    private static func waterCycleLogSnapshot(
        for pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> WaterCareCycleLogSnapshot {
        WaterCareCycleLogSnapshot(
            latestWaterChangeDate: latestCareEntryDate(.waterChange, pet: pet, careLedgerEntries: careLedgerEntries),
            latestFilterCleanDate: latestCareEntryDate(.filterClean, pet: pet, careLedgerEntries: careLedgerEntries)
        )
    }

    private static func latestCareEntryDate(
        _ type: CareType,
        pet: Pet,
        careLedgerEntries: [HomeCareQuickActionEntry]
    ) -> Date? {
        careLedgerEntries
            .filter { $0.petId == pet.id && $0.actionType == type.rawValue }
            .map(\.date)
            .max()
    }
}

private nonisolated struct HomeCarePlanEventIndex {
    private var statusEventsByTarget: [DomainMemberReference: [Event]] = [:]
    private var feedRuleEventsByPetID: [UUID: [Event]] = [:]

    init(
        pets: [Pet],
        humans: [Human],
        events: [Event],
        statusReminders: [Reminder]?,
        humanMedications: [HumanMedication]
    ) {
        let catalog = DomainSubjectResolutionCatalog(
            pets: pets,
            petMedications: pets.flatMap(\.medications),
            humanMedications: humanMedications,
            insurances: pets.flatMap(\.insurances),
            humans: humans
        )
        let statusEvents = statusReminders.map(Self.uniqueEvents(from:)) ?? events

        for event in statusEvents {
            let resolution = DomainSubjectResolver.resolve(
                request: DomainSubjectResolutionRequest(event: event),
                catalog: catalog
            )
            for target in resolution.lifecycleTargets {
                statusEventsByTarget[target, default: []].append(event)
            }
        }

        for event in events where event.eventType == EventType.foodChange.rawValue {
            let resolution = DomainSubjectResolver.resolve(
                request: DomainSubjectResolutionRequest(event: event),
                catalog: catalog
            )
            guard case let .pet(petID) = resolution.owner else { continue }
            feedRuleEventsByPetID[petID, default: []].append(event)
        }
    }

    func statusEvents(for target: DomainMemberReference) -> [Event] {
        statusEventsByTarget[target] ?? []
    }

    func feedRuleEvents(for petID: UUID) -> [Event] {
        feedRuleEventsByPetID[petID] ?? []
    }

    private static func uniqueEvents(from reminders: [Reminder]) -> [Event] {
        var seen = Set<UUID>()
        return reminders.compactMap { reminder in
            guard let event = reminder.event, seen.insert(event.id).inserted else { return nil }
            return event
        }
    }
}
