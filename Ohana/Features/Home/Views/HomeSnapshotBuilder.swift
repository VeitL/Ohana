//
//  HomeSnapshotBuilder.swift
//  Ohana
//
//  Pure home card snapshot aggregation.
//

import Foundation

enum HomeSnapshotBuilder {
    static func buildCards(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        events: [Event],
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        now: Date = Date()
    ) -> [FocusCard] {
        let statusEvents = actionableOverdueEvents(from: events, now: now)
        let medicationLogs = recentHumanMedicationLogs(from: humanMedicationLogs, now: now)
        return FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards
        )
        .map {
            decoratedStatusCard(
                $0,
                pets: pets,
                humans: humans,
                events: statusEvents,
                humanMedications: humanMedications,
                humanMedicationLogs: medicationLogs,
                now: now
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

    static func decoratedStatusCard(
        _ card: FocusCard,
        pets: [Pet],
        humans: [Human],
        events: [Event],
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        now: Date = Date()
    ) -> FocusCard {
        guard !card.isElectronicPet else {
            return card
        }

        let warning: CarePlanOverdueStatus?
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            warning = CarePlanOverdueStatusCalculator.humanWarning(
                for: human,
                events: events,
                medications: humanMedications,
                logs: humanMedicationLogs,
                now: now
            )
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            warning = CarePlanOverdueStatusCalculator.petWarning(for: pet, events: events, now: now)
        } else {
            warning = nil
        }

        guard let warning else { return card }
        var copy = card
        copy.statusBadgeText = warning.title
        copy.statusBadgeIsWarning = true
        return copy
    }
}
