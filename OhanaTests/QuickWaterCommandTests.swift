import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct QuickWaterCommandTests {
    @Test func waterPlanWriterReplacesOldPlanEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 6, day: 1, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()
        defer { clearWaterDefaults(for: pet) }

        let firstReminders = WaterPlanWriter.replacePlan(
            pet: pet,
            times: [
                date(year: 2026, month: 6, day: 1, hour: 10),
                date(year: 2026, month: 6, day: 1, hour: 18)
            ],
            allEvents: [],
            context: context,
            now: now
        )
        let firstEvents = try waterPlanEvents(context: context)
        #expect(firstEvents.count == 2)
        #expect(!firstReminders.isEmpty)

        _ = WaterPlanWriter.replacePlan(
            pet: pet,
            times: [date(year: 2026, month: 6, day: 1, hour: 12)],
            allEvents: firstEvents,
            context: context,
            now: now
        )
        let replacedEvents = try waterPlanEvents(context: context)
        let reminders = try context.fetch(FetchDescriptor<Reminder>())

        #expect(replacedEvents.count == 1)
        #expect(replacedEvents.first?.startDate == date(year: 2026, month: 6, day: 1, hour: 12))
        #expect(reminders.allSatisfy { $0.event?.id == replacedEvents.first?.id })
    }

    @Test func upcomingWaterPlanRemindersAreIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 6, day: 1, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Momo 喂水",
            startDate: date(year: 2026, month: 6, day: 1, hour: 10),
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        context.insert(pet)
        context.insert(event)
        try context.save()

        let first = WaterPlanWriter.ensureUpcomingReminders(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )
        let second = WaterPlanWriter.ensureUpcomingReminders(
            pet: pet,
            allEvents: [event],
            context: context,
            now: now
        )

        #expect(!first.isEmpty)
        #expect(second.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).count == first.count)
    }

    @Test func deleteWaterPlanRemovesEventsAndReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 6, day: 1, hour: 9)
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()
        defer { clearWaterDefaults(for: pet) }

        _ = WaterPlanWriter.replacePlan(
            pet: pet,
            times: [date(year: 2026, month: 6, day: 1, hour: 10)],
            allEvents: [],
            context: context,
            now: now
        )
        try WaterPlanWriter.deletePlan(pet: pet, allEvents: waterPlanEvents(context: context), context: context)

        #expect(try waterPlanEvents(context: context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func waterMaintenancePlanMatchingUsesStoredKindInsteadOfTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "鱼")
        context.insert(pet)
        try context.save()
        defer { clearWaterDefaults(for: pet) }

        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: context,
            intervalDays: 7,
            enabled: true,
            cycleAnchor: date(year: 2026, month: 6, day: 1)
        )
        let event = try #require(try context.fetch(FetchDescriptor<Event>()).first)
        event.title = "Momo water service"
        try context.save()

        let matched = try CarePlanCalendarSync.waterMaintenancePlanEvents(
            pet: pet,
            kinds: ["waterChange"],
            allEvents: context.fetch(FetchDescriptor<Event>())
        )

        #expect(matched.map(\.id) == [event.id])
        #expect(CarePlanCalendarSync.waterMaintenanceKind(for: event) == "waterChange")
    }

    @Test func waterNotificationTitlesLocalizeFromStructuredWaterKinds() throws {
        let event = Event(
            title: "Momo 换水",
            startDate: date(year: 2026, month: 6, day: 1, hour: 9),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        UserDefaults.standard.set(
            event.id.uuidString,
            forKey: "careCalendarEventId_waterChange_\(event.relatedEntityId)"
        )
        defer {
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_waterChange_\(event.relatedEntityId)")
        }

        #expect(WaterRuleMetadata.localizedTitle(for: event, l: L10n("en")) == "Change Momo's water")
        #expect(WaterRuleMetadata.localizedTitle(for: event, l: L10n("de")) == "Wasser von Momo wechseln")
    }

    @Test func quickWaterExecutorPublishesRevisionWhenSavingPlan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "猫")
        context.insert(pet)
        try context.save()
        defer { clearWaterDefaults(for: pet) }
        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        )

        _ = executor.saveWaterPlan(
            pet: pet,
            targets: [pet],
            times: [date(year: 2026, month: 6, day: 1, hour: 10)],
            count: 1,
            allEvents: []
        )

        #expect(center.lastMutation?.command.feature == "water")
        #expect(center.lastMutation?.command.action == "plan")
        #expect(center.homeRevision.value == 1)
    }

    @Test func plannedWaterCatchUpWithinSixHoursDoesNotAwardCoconuts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 6, day: 1, hour: 12)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Momo 喂水",
            startDate: date(year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: date(year: 2026, month: 6, day: 1, hour: 8))
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let reward = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: 120,
            context: context,
            executorId: "human-1",
            date: now
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(reward?.humanGot == 0)
        #expect(reward?.petGot == 0)
        #expect(reminder.isCompleted)
        #expect(logs.count == 1)
    }

    @Test func plannedWaterCatchUpAfterSixHoursIsRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 6, day: 1, hour: 16)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Momo 喂水",
            startDate: date(year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: date(year: 2026, month: 6, day: 1, hour: 8))
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let reward = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: 120,
            context: context,
            executorId: "human-1",
            date: now
        )

        #expect(reward == nil)
        #expect(reminder.isPending)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
    }

    @Test func waterRuleStateFiltersExpiredCatchUpReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let now = date(year: 2026, month: 6, day: 1, hour: 16)
        let event = Event(
            title: "Momo 喂水",
            startDate: date(year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let expired = Reminder(event: event, scheduledAt: date(year: 2026, month: 6, day: 1, hour: 8))
        let eligible = Reminder(event: event, scheduledAt: date(year: 2026, month: 6, day: 1, hour: 14))
        context.insert(pet)
        context.insert(event)
        context.insert(expired)
        context.insert(eligible)
        try context.save()
        let state = WaterRuleState(pet: pet, allEvents: [event], now: now)

        #expect(state.missedPlanReminders.map(\.id) == [eligible.id])
        #expect(state.expiredMissedPlanReminders.map(\.id) == [expired.id])
        #expect(state.nextPendingReminder == nil)
    }

    private func waterPlanEvents(context: ModelContext) throws -> [Event] {
        let entityType = WaterPlanWriter.entityType
        return try context.fetch(
            FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.relatedEntityType == entityType
                },
                sortBy: [SortDescriptor(\.startDate)]
            )
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV67.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date ?? Date(timeIntervalSince1970: 0)
    }

    private func clearWaterDefaults(for pet: Pet) {
        let petKey = pet.id.uuidString
        let prefixes = [
            "water_operating_mode_",
            "waterInterval_",
            "filterCleanInterval_",
            "filterReplaceInterval_",
            "waterReminder_",
            "filterReminder_",
            "waterAmountEnabled_",
            "waterAmountMl_",
            "waterChangeCycleAnchor_"
        ]
        for prefix in prefixes {
            UserDefaults.standard.removeObject(forKey: "\(prefix)\(petKey)")
        }
        for kind in ["drink", "waterChange", "filter", "filterClean", "filterReplace"] {
            UserDefaults.standard.removeObject(forKey: "careCalendarDefaultSuppressed_\(kind)_\(petKey)")
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_\(kind)_\(petKey)")
            UserDefaults.standard.removeObject(forKey: "careCalendarEventId_default_\(kind)_\(petKey)")
        }
    }
}
