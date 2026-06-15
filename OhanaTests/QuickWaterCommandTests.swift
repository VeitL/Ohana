import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
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
        #expect(CarePlanCalendarSync.waterMaintenanceKind(for: event, pet: pet) == "waterChange")
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

    @Test func quickWaterExecutorLatestAllEventsUsesFetchedStoreEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let later = Event(
            title: "Later",
            startDate: date(year: 2026, month: 6, day: 1, hour: 12),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        let earlier = Event(
            title: "Earlier",
            startDate: date(year: 2026, month: 6, day: 1, hour: 8),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        let fallback = Event(
            title: "Fallback",
            startDate: date(year: 2026, month: 6, day: 1, hour: 6),
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        context.insert(later)
        context.insert(earlier)
        try context.save()

        let events = QuickWaterCommandExecutor(context: context).latestAllEvents(fallback: [fallback])

        #expect(events.map(\.id) == [earlier.id, later.id])
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

    @Test func quickWaterExecutorNoopsForDeceasedPetAtCommandBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "猫")
        pet.passedAwayDate = date(year: 2026, month: 6, day: 1, hour: 9)
        context.insert(pet)
        try context.save()
        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        )

        let result = executor.recordWater(
            pet: pet,
            targets: [pet],
            amountMl: 120,
            executorId: "human-1"
        )

        #expect(result.coconutDelta == 0)
        #expect(result.targetCount == 0)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(center.homeRevision.value == 0)
        #expect(center.lastMutation == nil)
    }

    @Test func quickWaterExecutorWritesForMissingExecutorThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "猫")
        let activeHuman = Human(name: "Active")
        context.insert(pet)
        context.insert(activeHuman)
        try context.save()
        let cleanup = isolateEconomy(activeHumanID: activeHuman.id.uuidString, context: context, pets: [pet])
        defer { cleanup() }
        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        )

        let result = executor.recordWater(
            pet: pet,
            targets: [pet],
            amountMl: 120,
            executorId: UUID().uuidString
        )

        #expect(result.coconutDelta > 0)
        #expect(result.targetCount == 1)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<CoconutLedgerEntry>())).isEmpty)
        #expect(activeHuman.coconutBalance > 0)
        #expect(center.homeRevision.value == 1)
        #expect(center.lastMutation?.wroteBusinessFact == true)
    }

    @Test func plannedWaterCommandWritesForMissingExecutorDisposition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "猫")
        let scheduledAt = Date().addingTimeInterval(-60)
        let event = Event(
            title: "Momo 喂水",
            startDate: scheduledAt,
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()
        let cleanup = isolateEconomy(activeHumanID: nil, context: context, pets: [pet])
        defer { cleanup() }
        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        )

        let result = executor.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: 120,
            executorId: UUID().uuidString
        )

        #expect(result.didRecord)
        #expect(result.coconutDelta == 0)
        #expect(reminder.isCompleted)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(center.homeRevision.value == 1)
        #expect(center.lastMutation?.wroteBusinessFact == true)
    }

    @Test func quickWaterChangeWritesDerivedPlanForMissingExecutorDisposition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "鱼")
        context.insert(pet)
        try context.save()
        defer { clearWaterDefaults(for: pet) }
        let cleanup = isolateEconomy(activeHumanID: nil, context: context, pets: [pet])
        defer { cleanup() }
        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        )

        let result = executor.recordWaterChange(
            pet: pet,
            targets: [pet],
            allEvents: [],
            intervalDays: 7,
            reminderOn: true,
            cycleAnchor: date(year: 2026, month: 6, day: 1),
            executorId: UUID().uuidString
        )

        #expect(result.didRecord)
        #expect(!result.reminders.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<Event>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<Reminder>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(center.homeRevision.value > 0)
        #expect(center.lastMutation?.wroteBusinessFact == true)
    }

    @Test func filterCleanWritesDerivedPlanForMissingExecutorDisposition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let center = ReadModelRevisionCenter()
        let pet = Pet(name: "Momo", species: "鱼")
        context.insert(pet)
        try context.save()
        defer { clearWaterDefaults(for: pet) }
        let cleanup = isolateEconomy(activeHumanID: nil, context: context, pets: [pet])
        defer { cleanup() }
        let executor = QuickWaterCommandExecutor(
            context: context,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            careEvents: CareEventService(),
            userNotifications: SharedUserNotificationManager(),
            reminderScheduling: ReminderSchedulingManager(),
            revisions: SharedDomainRevisionPublisher(center: center)
        )

        let result = executor.recordFilterClean(
            pet: pet,
            targets: [pet],
            allEvents: [],
            cleanIntervalDays: 14,
            replaceIntervalDays: 60,
            reminderOn: true,
            executorId: UUID().uuidString
        )

        #expect(result.didRecord)
        #expect(!result.reminders.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<Event>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<Reminder>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(center.homeRevision.value > 0)
        #expect(center.lastMutation?.wroteBusinessFact == true)
    }

    @Test func plannedWaterCatchUpWithinSixHoursAwardsOnOperationDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(year: 2026, month: 6, day: 2, hour: 1)
        let scheduledAt = date(year: 2026, month: 6, day: 1, hour: 20)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "Momo 喂水",
            startDate: scheduledAt,
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: scheduledAt)
        let executorHuman = Human(name: "Guan")
        context.insert(pet)
        context.insert(executorHuman)
        context.insert(event)
        context.insert(reminder)
        try context.save()
        let defaults = UserDefaults.standard
        let oldActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let oldCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        let careObjectKeys = ["pet.\(pet.id.uuidString)"]
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey()
        defaults.set(executorHuman.id.uuidString, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: executorHuman.id.uuidString,
            careObjectKeys: careObjectKeys,
            date: scheduledAt
        )
        EconomyDailyBudgetStore.reset(
            householdKey: householdKey,
            memberKey: executorHuman.id.uuidString,
            careObjectKeys: careObjectKeys,
            date: now
        )
        defer {
            if let oldCooldownLogs {
                defaults.set(oldCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
            if let oldActiveHumanID {
                defaults.set(oldActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            EconomyDailyBudgetStore.reset(
                householdKey: householdKey,
                memberKey: executorHuman.id.uuidString,
                careObjectKeys: careObjectKeys,
                date: scheduledAt
            )
            EconomyDailyBudgetStore.reset(
                householdKey: householdKey,
                memberKey: executorHuman.id.uuidString,
                careObjectKeys: careObjectKeys,
                date: now
            )
        }

        let reward = CareEventService.completePlannedWater(
            pet: pet,
            reminder: reminder,
            amountMl: 120,
            context: context,
            executorId: "human-1",
            date: now
        )
        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        let careLedger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())
        let historicalDayKey = EconomyDailyBudgetStore.dayKey(for: scheduledAt)
        let operationDayKey = EconomyDailyBudgetStore.dayKey(for: now)

        #expect((reward?.humanGot ?? 0) + (reward?.petGot ?? 0) > 0)
        #expect(reminder.isCompleted)
        #expect(logs.count == 1)
        #expect(logs.first?.date == scheduledAt)
        #expect(careLedger.contains { $0.eventKindEnum == .care && $0.coconutDelta > 0 && $0.occurredAt == scheduledAt })
        #expect(budgetEvents.contains { $0.actionKey == "water" && $0.dayKey == operationDayKey })
        #expect(!budgetEvents.contains { $0.actionKey == "water" && $0.dayKey == historicalDayKey })
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
        let executorHuman = Human(name: "Guan")
        context.insert(pet)
        context.insert(executorHuman)
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

    private func isolateEconomy(activeHumanID: String?, context: ModelContext, pets: [Pet]) -> () -> Void {
        let defaults = UserDefaults.standard
        let previousActiveHumanID = defaults.object(forKey: "currentActiveHumanId")
        let previousCooldownLogs = defaults.object(forKey: QuestManager.Keys.cooldownLogs)
        if let activeHumanID {
            defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        } else {
            defaults.removeObject(forKey: "currentActiveHumanId")
        }
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        let careObjectKeys = pets.map(\.id.uuidString)
        EconomyDailyBudgetStore.reset(
            householdKey: CoconutEconomyPolicyV2.householdBudgetKey(context: context),
            memberKey: activeHumanID ?? "missing-owner",
            careObjectKeys: careObjectKeys
        )
        return {
            if let previousActiveHumanID {
                defaults.set(previousActiveHumanID, forKey: "currentActiveHumanId")
            } else {
                defaults.removeObject(forKey: "currentActiveHumanId")
            }
            if let previousCooldownLogs {
                defaults.set(previousCooldownLogs, forKey: QuestManager.Keys.cooldownLogs)
            } else {
                defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
            }
        }
    }
}
