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
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        careLedgerEntries: [HomeCareQuickActionEntry]? = nil,
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        now: Date = Date(),
        l: L10n = .current
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

    static func decoratedStatusCard(
        _ card: FocusCard,
        pets: [Pet],
        humans: [Human],
        events: [Event],
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        careLedgerEntries: [HomeCareQuickActionEntry]? = nil,
        now: Date = Date(),
        l: L10n = .current
    ) -> FocusCard {
        guard !card.isElectronicPet else {
            return card
        }

        let warning: CarePlanOverdueStatus? = if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
            CarePlanOverdueStatusCalculator.humanWarning(
                for: human,
                events: events,
                medications: humanMedications,
                logs: humanMedicationLogs,
                now: now
            )
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            CarePlanOverdueStatusCalculator.petWarning(
                for: pet,
                events: events,
                now: now,
                waterCycleLogSnapshot: careLedgerEntries.map { waterCycleLogSnapshot(for: pet, careLedgerEntries: $0) }
            )
        } else {
            nil
        }

        guard let warning else { return card }
        var copy = card
        copy.statusBadgeText = warning.localizedTitle(l: l)
        copy.statusBadgeIsWarning = true
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
