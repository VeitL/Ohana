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
                events: events,
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
        l _: L10n = .current
    ) -> FocusCard {
        guard !card.isElectronicPet else {
            return card
        }

        let urgentCount: Int
        let dueCount: Int
        if card.isHuman, let human = humans.first(where: { $0.id == card.id }) {
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
            let waterCycleSnapshot = careLedgerEntries.map { waterCycleLogSnapshot(for: pet, careLedgerEntries: $0) }
            urgentCount = CarePlanOverdueStatusCalculator.petWarningCount(
                for: pet,
                events: events,
                now: now,
                waterCycleLogSnapshot: waterCycleSnapshot
            )
            dueCount = CarePlanOverdueStatusCalculator.petDueTodayCount(
                pet: pet,
                events: events,
                now: now,
                waterCycleLogSnapshot: waterCycleSnapshot
            )
        } else {
            urgentCount = 0
            dueCount = 0
        }

        var copy = card
        if urgentCount > 0 {
            copy.statusBadgeText = badgeCountText(urgentCount)
            copy.statusBadgeTone = .urgent
        } else if dueCount > 0 {
            copy.statusBadgeText = badgeCountText(dueCount)
            copy.statusBadgeTone = .due
        } else {
            copy.statusBadgeText = nil
            copy.statusBadgeTone = .ok
        }
        return copy
    }

    private static func badgeCountText(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
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
