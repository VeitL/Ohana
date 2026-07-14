import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct MemberLifecycleGateTests {
    @Test func activeCareAllowsFactDerivedEffectsAndEconomy() {
        let pet = Pet(name: "Momo", species: "cat")

        let disposition = MemberLifecycleGate.disposition(pet: pet, writeKind: .care)

        #expect(disposition.isAllowed)
        #expect(disposition.writesContent)
        #expect(disposition.allowsCareFactWrite)
        #expect(disposition.allowsDerivedEffects)
        #expect(disposition.allowsEconomyDerivation)
        #expect(disposition.allowsRevisionPublish)
    }

    @Test func deceasedCareAndProfileEditDenyWrites() {
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_101)
        let human = Human(name: "Ava")
        human.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_102)

        let petCare = MemberLifecycleGate.disposition(pet: pet, writeKind: .care)
        let humanProfile = MemberLifecycleGate.disposition(human: human, writeKind: .profileEdit)

        #expect(petCare.denialReason == .memberPassedAway)
        #expect(!petCare.writesContent)
        #expect(!petCare.allowsCareFactWrite)
        #expect(!petCare.allowsDerivedEffects)
        #expect(!petCare.allowsEconomyDerivation)
        #expect(humanProfile.denialReason == .memberPassedAway)
        #expect(!humanProfile.writesContent)
    }

    @Test func memorialContentAllowsContentButNoCareOrEconomyDerivation() {
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_103)
        let human = Human(name: "Ava")

        let deceasedPet = MemberLifecycleGate.disposition(pet: pet, writeKind: .memorial)
        let activeHuman = MemberLifecycleGate.disposition(human: human, writeKind: .memorial)

        for disposition in [deceasedPet, activeHuman] {
            #expect(disposition.isAllowed)
            #expect(disposition.writesContent)
            #expect(!disposition.allowsCareFactWrite)
            #expect(!disposition.allowsDerivedEffects)
            #expect(!disposition.allowsEconomyDerivation)
            #expect(disposition.allowsRevisionPublish)
        }
    }

    @Test func legacyMemberWritePolicyAndWalletPolicyDelegateToLifecycleGate() {
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Ava")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_104)
        human.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_105)

        #expect(MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).denialReason == .memberPassedAway)
        #expect(MemberWritePolicy.disposition(pet: pet, intent: .memorialContent).writesContent)
        #expect(!MemberWritePolicy.disposition(pet: pet, intent: .memorialContent).allowsEconomyDerivation)
        #expect(!EconomyWalletWritePolicy.canWrite(pet))
        #expect(!EconomyWalletWritePolicy.canWrite(human))
    }

    @Test func lifecycleActionsSeparateExplicitDeathChangesFromCareCleanup() {
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_106)

        let undoDeath = MemberLifecycleGate.disposition(pet: pet, writeKind: .lifecycle(.undoPassedAway))
        let cleanup = MemberLifecycleGate.disposition(pet: pet, writeKind: .lifecycle(.clearActivityRecords))

        #expect(undoDeath.isAllowed)
        #expect(cleanup.denialReason == .memberPassedAway)
        #expect(!cleanup.writesContent)
    }

    @Test func lifecycleScheduleCleanupAllowsOnlyCleanupEffects() {
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_106)

        let cleanup = MemberLifecycleGate.disposition(pet: pet, writeKind: .lifecycle(.cleanupActiveSchedules))

        #expect(cleanup.isAllowed)
        #expect(!cleanup.writesContent)
        #expect(!cleanup.allowsCareFactWrite)
        #expect(cleanup.allowsDerivedEffects)
        #expect(!cleanup.allowsEconomyDerivation)
        #expect(!cleanup.allowsRevisionPublish)
    }

    @Test func deceasedMembersCannotCreateActiveCalendarOrHygienePlans() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_107)
        let human = Human(name: "Ava")
        human.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_108)
        context.insert(pet)
        context.insert(human)
        try context.save()

        let petPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Vet visit",
                startDate: Date(timeIntervalSince1970: 1_800_000_200),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString,
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )
        let humanPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Check in",
                startDate: Date(timeIntervalSince1970: 1_800_000_300),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: human.id.uuidString,
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )
        let deceasedAssigneePlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Assigned task",
                startDate: Date(timeIntervalSince1970: 1_800_000_350),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: "",
                relatedEntityId: "",
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: human.id.uuidString
            ),
            context: context,
            scheduleNotifications: false
        )
        let hygienePlan = PetHygieneCommandService.createPlan(
            pet: pet,
            type: .brushing,
            input: PetHygienePlanCommandInput(
                startDate: Date(timeIntervalSince1970: 1_800_000_400),
                isAllDay: false,
                startTime: Date(timeIntervalSince1970: 1_800_000_400),
                hasEndDate: false,
                endDate: Date(timeIntervalSince1970: 1_800_000_400),
                repeatDays: 0,
                customNote: ""
            ),
            context: context,
            scheduleNotification: false
        )

        #expect(petPlan == nil)
        #expect(humanPlan == nil)
        #expect(deceasedAssigneePlan == nil)
        #expect(!hygienePlan.didCreate)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func calendarPlanGateFindsDeceasedMemberWhenOtherMembersExist() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activePet = Pet(name: "Nori", species: "cat")
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_110)
        let activeHuman = Human(name: "Ava")
        let deceasedHuman = Human(name: "Guan")
        deceasedHuman.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_111)
        for member in [activePet, deceasedPet] {
            context.insert(member)
        }
        for member in [activeHuman, deceasedHuman] {
            context.insert(member)
        }
        try context.save()

        let petPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Vet visit",
                startDate: Date(timeIntervalSince1970: 1_800_000_600),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: deceasedPet.id.uuidString,
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )
        let humanPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Check in",
                startDate: Date(timeIntervalSince1970: 1_800_000_700),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: deceasedHuman.id.uuidString,
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )

        #expect(petPlan == nil)
        #expect(humanPlan == nil)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func missingMemberTargetsCannotCreateCalendarPlans() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let missingPetID = UUID()
        let missingHumanID = UUID()

        let petPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Vet visit",
                startDate: Date(timeIntervalSince1970: 1_800_000_710),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: missingPetID.uuidString,
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )
        let humanPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Check in",
                startDate: Date(timeIntervalSince1970: 1_800_000_720),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: missingHumanID.uuidString,
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )
        let invalidPetPlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Bad target",
                startDate: Date(timeIntervalSince1970: 1_800_000_730),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: "missing",
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )
        let missingAssigneePlan = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Missing assignee",
                startDate: Date(timeIntervalSince1970: 1_800_000_740),
                isAllDay: false,
                eventType: .task,
                relatedEntityType: "",
                relatedEntityId: "",
                recurrenceDays: 0,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: missingHumanID.uuidString
            ),
            context: context,
            scheduleNotifications: false
        )

        #expect(petPlan == nil)
        #expect(humanPlan == nil)
        #expect(invalidPetPlan == nil)
        #expect(missingAssigneePlan == nil)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func deceasedPetCannotWriteDirectFeedingPlansOrStockRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_112)
        context.insert(pet)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_800_000_800)
        let draft = FeedPlanDraft(
            kind: .manualReminder,
            dailyCount: 1,
            gramsPerMeal: 40,
            times: [now],
            now: now
        )
        let result = try FeedingPlanWriter.replacePlan(
            pet: pet,
            draft: draft,
            allEvents: [],
            context: context,
            now: now
        )
        _ = try FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: "Test",
            totalGrams: 1000,
            purchaseDate: now,
            dailyGrams: 50,
            reminderEnabled: true,
            reminderAdvanceDays: 2,
            executorId: nil,
            allEvents: [],
            context: context
        )

        #expect(result.events.isEmpty)
        #expect(result.reminders.isEmpty)
        #expect(pet.dailyPortionGrams == 0)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetFoodRecord>()).isEmpty)
    }

    @Test func deceasedPetCannotWriteWaterOrCarePlanSchedules() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_114)
        context.insert(pet)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_800_001_300)
        _ = try WaterPlanWriter.replacePlan(
            pet: pet,
            times: [now],
            allEvents: [],
            context: context,
            now: now
        )
        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: context,
            intervalDays: 7,
            enabled: true,
            cycleAnchor: now
        )
        CarePlanCalendarSync.syncFilterPlan(
            pet: pet,
            context: context,
            cleanIntervalDays: 7,
            replaceIntervalDays: 30,
            enabled: true
        )
        CarePlanCalendarSync.syncScoopPlan(
            pet: pet,
            context: context,
            intervalDays: 1,
            enabled: true,
            anchor: now
        )
        CarePlanCalendarSync.syncPlayPlan(
            pet: pet,
            context: context,
            intervalDays: 3,
            enabled: true,
            anchor: now
        )

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func deceasedPetQuickWaterWrappersDoNotPersistSettingsOrMode() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "fish")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_116)
        context.insert(pet)
        try context.save()

        let now = Date(timeIntervalSince1970: 1_800_001_320)
        let executor = QuickWaterCommandExecutor(context: context)
        executor.persistWaterSettings(pet: pet, intervalDays: 9, reminderOn: true, cycleAnchor: now)
        executor.persistWaterAmountSettings(pet: pet, enabled: false, amountMl: 880)
        executor.persistFilterSettings(pet: pet, cleanIntervalDays: 5, replaceIntervalDays: 25, reminderOn: true)
        let waterChange = executor.saveWaterChangePlan(
            pet: pet,
            allEvents: [],
            intervalDays: 9,
            reminderOn: true,
            cycleAnchor: now
        )
        let filter = executor.syncFilterPlan(
            pet: pet,
            allEvents: [],
            cleanIntervalDays: 5,
            replaceIntervalDays: 25,
            reminderOn: true
        )
        let plan = try executor.saveWaterPlan(pet: pet, targets: [pet], times: [now], count: 1, allEvents: [])
        executor.setWaterMode(.reminder, pet: pet)

        let snapshot = WaterCareSettingsStore.snapshot(petKey: pet.id.uuidString, now: now)
        #expect(waterChange.isEmpty)
        #expect(filter.isEmpty)
        #expect(plan.targetCount == 0)
        #expect(plan.reminders.isEmpty)
        #expect(WaterOperatingMode.stored(pet.id) == nil)
        #expect(snapshot.waterIntervalDays == 3)
        #expect(snapshot.filterCleanIntervalDays == 14)
        #expect(snapshot.filterReplaceIntervalDays == 90)
        #expect(!snapshot.waterReminderOn)
        #expect(!snapshot.filterReminderOn)
        #expect(snapshot.waterAmountEnabled)
        #expect(snapshot.waterAmountMl == 250)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func deceasedHumanNoteWithReminderWritesMemorialContentOnly() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        human.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_117)
        context.insert(human)
        try context.save()

        let result = HumanNoteCommandService.recordNote(
            human: human,
            note: "A favorite memory",
            date: Date(timeIntervalSince1970: 1_800_001_330),
            imageAttachments: [],
            fileAttachments: [],
            reminderDate: Date(timeIntervalSince1970: 1_800_002_000),
            appLanguage: AppLanguage.fallbackCode,
            context: context,
            scheduleNotification: false
        )

        #expect(result?.subjectID == human.id)
        #expect(result?.eventID == nil)
        #expect(result?.reminderID == nil)
        #expect(human.notes.contains("A favorite memory"))
        #expect(!human.notes.contains("Reminder:"))
        #expect(!human.notes.contains("提醒："))
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func deceasedPetCanCreateMemorialCalendarDateWithoutReminder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_118)
        context.insert(pet)
        try context.save()

        let result = try CalendarEventPlanCommandService.createEvent(
            input: CalendarEventPlanCommandInput(
                title: "Momo day",
                startDate: Date(timeIntervalSince1970: 1_800_002_200),
                isAllDay: true,
                eventType: .anniversary,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString,
                recurrenceDays: 365,
                recurrenceEndDate: nil,
                reminderLeadMinutes: 30,
                assigneeId: nil
            ),
            context: context,
            scheduleNotifications: false
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        let createdEvent = try #require(events.first)
        #expect(result != nil)
        #expect(result?.reminderIDs.isEmpty == true)
        #expect(events.count == 1)
        #expect(createdEvent.eventType == EventType.anniversary.rawValue)
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(createdEvent, now: Date(timeIntervalSince1970: 1_800_001_400)))
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func markingPetPassedAwayRemovesFutureActiveSchedules() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "cat")
        let passDate = Date(timeIntervalSince1970: 1_800_001_400)
        let future = passDate.addingTimeInterval(3600)
        let past = passDate.addingTimeInterval(-3600)
        let futureEvent = Event(
            title: "Future care",
            startDate: future,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let pastEvent = Event(
            title: "Past care",
            startDate: past,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let otherFutureEvent = Event(
            title: "Other future care",
            startDate: future,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: otherPet.id.uuidString
        )
        let futureReminder = Reminder(event: futureEvent, scheduledAt: future)
        let pastReminder = Reminder(event: pastEvent, scheduledAt: past)
        let otherFutureReminder = Reminder(event: otherFutureEvent, scheduledAt: future)
        futureReminder.notificationId = "memorial-pet-future"
        pastReminder.notificationId = "memorial-pet-past"
        otherFutureReminder.notificationId = "memorial-other-pet-future"
        let futureEventID = futureEvent.id
        let pastEventID = pastEvent.id
        let otherFutureEventID = otherFutureEvent.id
        let futureReminderID = futureReminder.id
        let pastReminderID = pastReminder.id
        let otherFutureReminderID = otherFutureReminder.id
        context.insert(pet)
        context.insert(otherPet)
        context.insert(futureEvent)
        context.insert(pastEvent)
        context.insert(otherFutureEvent)
        context.insert(futureReminder)
        context.insert(pastReminder)
        context.insert(otherFutureReminder)
        try context.save()
        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }

        _ = MemberLifecycleCommandService.markPetPassedAway(pet, date: passDate, context: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(pet.passedAwayDate == passDate)
        #expect(!events.contains { $0.id == futureEventID })
        #expect(!reminders.contains { $0.id == futureReminderID })
        #expect(events.contains { $0.id == pastEventID })
        #expect(reminders.contains { $0.id == pastReminderID })
        #expect(events.contains { $0.id == otherFutureEventID })
        #expect(reminders.contains { $0.id == otherFutureReminderID })
        #expect(scheduler.cancelledNotificationIds == ["memorial-pet-future"])
    }

    @Test func markingHumanPassedAwayRemovesFutureActiveSchedulesAndCancelsNotifications() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let otherHuman = Human(name: "Guan")
        let passDate = Date(timeIntervalSince1970: 1_800_001_410)
        let future = passDate.addingTimeInterval(3600)
        let past = passDate.addingTimeInterval(-3600)
        let futureEvent = Event(
            title: "Future human care",
            startDate: future,
            eventType: EventType.health.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString
        )
        let pastEvent = Event(
            title: "Past human care",
            startDate: past,
            eventType: EventType.health.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString
        )
        let otherFutureEvent = Event(
            title: "Other human care",
            startDate: future,
            eventType: EventType.health.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: otherHuman.id.uuidString
        )
        let futureReminder = Reminder(event: futureEvent, scheduledAt: future)
        let pastReminder = Reminder(event: pastEvent, scheduledAt: past)
        let otherFutureReminder = Reminder(event: otherFutureEvent, scheduledAt: future)
        futureReminder.notificationId = "memorial-human-future"
        pastReminder.notificationId = "memorial-human-past"
        otherFutureReminder.notificationId = "memorial-other-human-future"
        let futureEventID = futureEvent.id
        let pastEventID = pastEvent.id
        let otherFutureEventID = otherFutureEvent.id
        let futureReminderID = futureReminder.id
        let pastReminderID = pastReminder.id
        let otherFutureReminderID = otherFutureReminder.id
        context.insert(human)
        context.insert(otherHuman)
        context.insert(futureEvent)
        context.insert(pastEvent)
        context.insert(otherFutureEvent)
        context.insert(futureReminder)
        context.insert(pastReminder)
        context.insert(otherFutureReminder)
        try context.save()
        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }

        _ = MemberLifecycleCommandService.markHumanPassedAway(human, date: passDate, context: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(human.passedAwayDate == passDate)
        #expect(!events.contains { $0.id == futureEventID })
        #expect(!reminders.contains { $0.id == futureReminderID })
        #expect(events.contains { $0.id == pastEventID })
        #expect(reminders.contains { $0.id == pastReminderID })
        #expect(events.contains { $0.id == otherFutureEventID })
        #expect(reminders.contains { $0.id == otherFutureReminderID })
        #expect(scheduler.cancelledNotificationIds == ["memorial-human-future"])
    }

    @Test func foodStockReminderUsesUnifiedPetResolver() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let passDate = Date(timeIntervalSince1970: 1_800_001_450)
        let event = Event(
            title: "Stock",
            startDate: passDate.addingTimeInterval(3600),
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        let eventID = event.id
        let reminderID = reminder.id
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        #expect(MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: pet.id.uuidString))
        pet.passedAwayDate = passDate
        #expect(MemberLifecycleActiveScheduleResolver.eventTargetsDeceasedActiveSchedule(event, pets: [pet], humans: [], now: passDate))

        _ = MemberLifecycleCommandService.markPetPassedAway(pet, date: passDate, context: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(!events.contains { $0.id == eventID })
        #expect(!reminders.contains { $0.id == reminderID })
    }

    @Test func activeScheduleResolverCoversMemberOwnershipMatrix() {
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "cat")
        let human = Human(name: "Ava")
        let otherHuman = Human(name: "Guan")
        let petMedication = PetMedication(name: "Drops", pet: pet)
        let humanMedication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin")
        let insurance = PetInsurance(companyName: "Care", pet: pet)

        let directPet = Event(
            title: "Pet care",
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let directHuman = Event(
            title: "Human check",
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString
        )
        let foodStock = Event(
            title: "Food stock",
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        let petMedicationEvent = Event(
            title: "Pet medication",
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: petMedication.id.uuidString
        )
        let humanMedicationEvent = Event(
            title: "Human medication",
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString
        )
        let insuranceEvent = Event(
            title: "Insurance",
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        )
        let humanNote = Event(
            title: "Human note",
            relatedEntityType: DomainEntityLinkRegistry.humanNote,
            relatedEntityId: human.id.uuidString
        )
        let assignedPetEvent = Event(
            title: "Assigned pet task",
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        assignedPetEvent.assigneeId = human.id.uuidString
        let assignedOnlyEvent = Event(title: "Assigned household task")
        assignedOnlyEvent.assigneeId = human.id.uuidString
        let missingAssignedOnlyEvent = Event(title: "Missing assignee household task")
        missingAssignedOnlyEvent.assigneeId = UUID().uuidString
        let reminderOnly = Reminder(event: nil, scheduledAt: Date(timeIntervalSince1970: 1_800_003_000))
        let catalog = DomainSubjectResolutionCatalog(
            pets: [pet, otherPet],
            petMedications: [petMedication],
            humanMedications: [humanMedication],
            insurances: [insurance],
            humans: [human, otherHuman]
        )

        #expect(MemberLifecycleActiveScheduleResolver.petTarget(for: directPet, pets: [pet, otherPet])?.id == pet.id)
        #expect(MemberLifecycleActiveScheduleResolver.humanOwner(for: directHuman, humans: [human, otherHuman], humanMedications: [])?.id == human.id)
        #expect(MemberLifecycleActiveScheduleResolver.petTarget(for: foodStock, pets: [pet, otherPet])?.id == pet.id)
        #expect(MemberLifecycleActiveScheduleResolver.petTarget(
            for: petMedicationEvent,
            pets: [pet, otherPet],
            petMedications: [petMedication]
        )?.id == pet.id)
        #expect(MemberLifecycleActiveScheduleResolver.humanOwner(for: humanMedicationEvent, humans: [human, otherHuman], humanMedications: [humanMedication])?.id == human.id)
        #expect(MemberLifecycleActiveScheduleResolver.petTarget(
            for: insuranceEvent,
            pets: [pet, otherPet],
            insurances: [insurance]
        )?.id == pet.id)
        #expect(MemberLifecycleActiveScheduleResolver.humanOwner(for: humanNote, humans: [human, otherHuman], humanMedications: [])?.id == human.id)
        #expect(MemberLifecycleActiveScheduleResolver.humanInvolved(in: assignedPetEvent, humans: [human, otherHuman], humanMedications: [])?.id == human.id)
        #expect(MemberLifecycleActiveScheduleResolver.humanOwner(for: assignedPetEvent, humans: [human, otherHuman], humanMedications: []) == nil)
        #expect(MemberLifecycleActiveScheduleResolver.humanInvolved(in: assignedOnlyEvent, humans: [human, otherHuman], humanMedications: [])?.id == human.id)
        #expect(MemberLifecycleActiveScheduleResolver.humanInvolved(in: missingAssignedOnlyEvent, humans: [human, otherHuman], humanMedications: []) == nil)
        let missingAssigneeResolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: missingAssignedOnlyEvent),
            catalog: catalog
        )
        #expect(missingAssigneeResolution.assignee == nil)
        #expect(missingAssigneeResolution.unresolvedAssignee)
        #expect(MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(reminderOnly, activePets: [], activeHumans: []))
        #expect(DomainSubjectResolver.resolve(request: DomainSubjectResolutionRequest(
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        ), catalog: catalog).owner == .pet(pet.id))
        #expect(DomainSubjectResolver.resolve(request: DomainSubjectResolutionRequest(
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString
        ), catalog: catalog).owner == .human(human.id))
        let missingDirectPetResolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: UUID().uuidString
            ),
            catalog: catalog
        )
        #expect(missingDirectPetResolution.owner == nil)
        #expect(missingDirectPetResolution.unresolvedOwner)
    }

    @Test func scheduleRehydrateQuarantinesUnregisteredLinksBeforePersistence() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let snapshot = DomainScheduleRehydrateEventSnapshot(
            id: UUID(),
            title: "Unknown remote plan",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            endDate: nil,
            isAllDay: false,
            eventType: EventType.task.rawValue,
            relatedEntityType: "new_remote_member_link",
            relatedEntityId: UUID().uuidString,
            recurrenceDays: 1,
            recurrenceEndDate: Date(timeIntervalSince1970: 1_900_086_400),
            isCompleted: false,
            completedOccurrences: [],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            assigneeId: nil,
            feedRuleKindRaw: "",
            foodKindRaw: FeedFoodKind.dry.rawValue,
            feedAmountGrams: 0,
            feedPlanGroupId: ""
        )

        let result = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )

        #expect(result.event == nil)
        #expect(!result.inserted)
        if case let .quarantined(unregisteredType) = result.plan.disposition {
            #expect(unregisteredType == "new_remote_member_link")
        } else {
            Issue.record("Expected unregistered schedule link to be quarantined.")
        }
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
    }

    @Test func scheduleRehydrateMakesUnresolvedOwnerHistoryOnly() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let snapshot = DomainScheduleRehydrateEventSnapshot(
            id: UUID(),
            title: "Missing pet plan",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            endDate: nil,
            isAllDay: false,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString,
            recurrenceDays: 1,
            recurrenceEndDate: Date(timeIntervalSince1970: 1_900_086_400),
            isCompleted: false,
            completedOccurrences: [],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            assigneeId: nil,
            feedRuleKindRaw: "",
            foodKindRaw: FeedFoodKind.dry.rawValue,
            feedAmountGrams: 0,
            feedPlanGroupId: ""
        )

        let result = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )
        let event = try #require(result.event)

        #expect(result.inserted)
        #expect(result.plan.disposition == .legacyHistoryOnly)
        #expect(event.isCompleted)
        #expect(event.recurrenceDays == 0)
        #expect(event.recurrenceEndDate == nil)
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(
            event,
            now: Date(timeIntervalSince1970: 1_899_999_000)
        ))
    }

    @Test func scheduleRehydrateHistoryOnlyTerminalizesExistingReminders() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let event = Event(
            title: "Existing plan",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.recurrenceEndDate = Date(timeIntervalSince1970: 1_900_086_400)
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSince1970: 1_900_000_500))
        reminder.status = ReminderStatus.pending.rawValue
        reminder.notificationId = "history-existing-reminder"
        event.reminders = [reminder]
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let snapshot = DomainScheduleRehydrateEventSnapshot(
            id: event.id,
            title: "Missing pet plan",
            startDate: event.startDate,
            endDate: nil,
            isAllDay: false,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString,
            recurrenceDays: 1,
            recurrenceEndDate: Date(timeIntervalSince1970: 1_900_086_400),
            isCompleted: false,
            completedOccurrences: [],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            assigneeId: nil,
            feedRuleKindRaw: "",
            foodKindRaw: FeedFoodKind.dry.rawValue,
            feedAmountGrams: 0,
            feedPlanGroupId: ""
        )

        let result = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )

        #expect(result.event?.id == event.id)
        #expect(!result.inserted)
        #expect(result.plan.disposition == .legacyHistoryOnly)
        #expect(event.isCompleted)
        #expect(event.recurrenceDays == 0)
        #expect(reminder.statusEnum == .skipped)
        #expect(result.notificationIdsToCancel == ["history-existing-reminder"])
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(
            event,
            now: Date(timeIntervalSince1970: 1_899_999_000)
        ))
    }

    @Test func scheduleRehydrateQuarantineNeutralizesExistingScheduleWithoutPersistingRawLink() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let event = Event(
            title: "Existing plan",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSince1970: 1_900_000_500))
        reminder.status = ReminderStatus.pending.rawValue
        reminder.notificationId = "quarantine-existing-reminder"
        event.reminders = [reminder]
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let snapshot = DomainScheduleRehydrateEventSnapshot(
            id: event.id,
            title: "Unknown remote plan",
            startDate: event.startDate,
            endDate: nil,
            isAllDay: false,
            eventType: EventType.task.rawValue,
            relatedEntityType: "new_remote_member_link",
            relatedEntityId: UUID().uuidString,
            recurrenceDays: 1,
            recurrenceEndDate: Date(timeIntervalSince1970: 1_900_086_400),
            isCompleted: false,
            completedOccurrences: [],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            assigneeId: nil,
            feedRuleKindRaw: "",
            foodKindRaw: FeedFoodKind.dry.rawValue,
            feedAmountGrams: 0,
            feedPlanGroupId: ""
        )

        let result = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: snapshot,
            source: .cloudApply,
            context: context
        )

        #expect(result.event?.id == event.id)
        #expect(!result.inserted)
        if case let .quarantined(unregisteredType) = result.plan.disposition {
            #expect(unregisteredType == "new_remote_member_link")
        } else {
            Issue.record("Expected unregistered schedule link to be quarantined.")
        }
        #expect(event.relatedEntityType == EntityKind.pet.rawValue)
        #expect(event.relatedEntityId == pet.id.uuidString)
        #expect(event.isCompleted)
        #expect(event.recurrenceDays == 0)
        #expect(reminder.statusEnum == .skipped)
        #expect(result.notificationIdsToCancel == ["quarantine-existing-reminder"])
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(
            event,
            now: Date(timeIntervalSince1970: 1_899_999_000)
        ))
    }

    @Test func backupRestoreRehydratesExistingSchedulesThroughWriter() throws {
        let suiteName = "OhanaTests.BackupScheduleRehydrate.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataBackupManager(defaults: defaults)
        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let eventId = UUID()
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let missingPetEvent = Event(
            title: "Missing pet plan",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        missingPetEvent.id = eventId
        missingPetEvent.recurrenceDays = 1
        missingPetEvent.recurrenceEndDate = Date(timeIntervalSince1970: 1_900_086_400)
        sourceContext.insert(missingPetEvent)
        try sourceContext.save()
        let backup = try manager.buildBackup(context: sourceContext)

        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let existingEvent = Event(
            title: "Existing plan",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        existingEvent.id = eventId
        existingEvent.recurrenceDays = 1
        let reminder = Reminder(event: existingEvent, scheduledAt: Date(timeIntervalSince1970: 1_900_000_500))
        reminder.status = ReminderStatus.pending.rawValue
        reminder.notificationId = "restore-existing-reminder"
        existingEvent.reminders = [reminder]
        targetContext.insert(pet)
        targetContext.insert(existingEvent)
        targetContext.insert(reminder)
        try targetContext.save()

        try manager.applyBackup(backup, context: targetContext, projectionManager: nil)

        #expect(existingEvent.title == "Missing pet plan")
        #expect(existingEvent.isCompleted)
        #expect(existingEvent.recurrenceDays == 0)
        #expect(reminder.statusEnum == .skipped)
        #expect(scheduler.cancelledNotificationIds == ["restore-existing-reminder"])
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(
            existingEvent,
            now: Date(timeIntervalSince1970: 1_899_999_000)
        ))
    }

    @Test func scheduleRehydrateSkipsReminderWithoutResolvedEvent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let snapshot = DomainScheduleRehydrateReminderSnapshot(
            id: UUID(),
            scheduledAt: Date(timeIntervalSince1970: 1_900_000_000),
            status: ReminderStatus.pending.rawValue,
            notificationId: UUID().uuidString,
            eventId: UUID(),
            completedAt: nil,
            completedBy: "",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let result = try DomainScheduleRehydrateWriter.upsertReminder(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )

        #expect(result.reminder == nil)
        #expect(!result.inserted)
        #expect(result.plan.disposition == .legacyHistoryOnly)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func scheduleRehydrateSkipsExistingReminderWhenLinkedEventIsMissing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "Local orphan source", startDate: Date(timeIntervalSince1970: 1_900_000_000))
        event.recurrenceDays = 1
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSince1970: 1_900_000_500))
        reminder.status = ReminderStatus.pending.rawValue
        reminder.notificationId = "local-orphan-reminder"
        event.reminders = [reminder]
        context.insert(event)
        context.insert(reminder)
        try context.save()
        let snapshot = DomainScheduleRehydrateReminderSnapshot(
            id: reminder.id,
            scheduledAt: reminder.scheduledAt,
            status: ReminderStatus.pending.rawValue,
            notificationId: "remote-orphan-reminder",
            eventId: UUID(),
            completedAt: nil,
            completedBy: "",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let result = try DomainScheduleRehydrateWriter.upsertReminder(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )

        #expect(result.reminder?.id == reminder.id)
        #expect(!result.inserted)
        #expect(result.plan.disposition == .legacyHistoryOnly)
        #expect(event.isCompleted)
        #expect(event.recurrenceDays == 0)
        #expect(reminder.statusEnum == .skipped)
        #expect(result.notificationIdsToCancel == ["local-orphan-reminder"])
        #expect(!MemberLifecycleActiveScheduleResolver.isActiveSchedule(
            event,
            now: Date(timeIntervalSince1970: 1_899_999_000)
        ))
    }

    @Test func domainScheduleResolutionAndAuthorizationCoverIndirectMembers() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Ava")
        let petMedication = PetMedication(name: "Drops", pet: pet)
        let humanMedication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        context.insert(pet)
        context.insert(human)
        context.insert(petMedication)
        context.insert(humanMedication)
        context.insert(insurance)
        try context.save()

        let stockIntent = DomainScheduleCreateIntent(
            title: "Food stock",
            startDate: Date(timeIntervalSince1970: 1_800_003_100),
            relatedEntityType: DomainEntityLinkRegistry.petFoodStock,
            relatedEntityId: "\(pet.id.uuidString):dry",
            writeKind: .care
        )
        let petMedicationIntent = DomainScheduleCreateIntent(
            title: "Pet medication",
            startDate: Date(timeIntervalSince1970: 1_800_003_200),
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: petMedication.id.uuidString,
            writeKind: .care
        )
        let humanMedicationIntent = DomainScheduleCreateIntent(
            title: "Human medication",
            startDate: Date(timeIntervalSince1970: 1_800_003_300),
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString,
            writeKind: .care
        )
        let insuranceIntent = DomainScheduleCreateIntent(
            title: "Insurance",
            startDate: Date(timeIntervalSince1970: 1_800_003_400),
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString,
            writeKind: .care
        )

        #expect(DomainScheduleSubjectResolver.resolve(intent: stockIntent, context: context).owner == .pet(pet.id))
        #expect(DomainScheduleSubjectResolver.resolve(intent: petMedicationIntent, context: context).owner == .pet(pet.id))
        #expect(DomainScheduleSubjectResolver.resolve(intent: humanMedicationIntent, context: context).owner == .human(human.id))
        #expect(DomainScheduleSubjectResolver.resolve(intent: insuranceIntent, context: context).owner == .pet(pet.id))
        #expect(DomainScheduleWriteAuthorizer.authorizeCreate(intent: insuranceIntent, context: context) != nil)

        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_003_500)

        #expect(DomainScheduleWriteAuthorizer.authorizeCreate(intent: insuranceIntent, context: context) == nil)
    }

    @Test func domainSubjectResolutionSeparatesOwnerAssigneeDisplayAndEffects() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Ava")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString,
                assigneeId: human.id.uuidString
            ),
            context: context
        )

        #expect(resolution.owner == .pet(pet.id))
        #expect(resolution.assignee == .human(human.id))
        #expect(resolution.displayTarget == .pet(pet.id))
        #expect(resolution.effectTargets == [.pet(pet.id), .human(human.id)])
        #expect(resolution.lifecycleTargets == [.pet(pet.id), .human(human.id)])
        #expect(!resolution.hasUnregisteredLinkType)
    }

    @Test func domainResolvedSubjectKeyNormalizesOwnerAliasesAndCompoundLinks() {
        let pet = Pet(name: "Momo", species: "cat")
        let directPet = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            ),
            catalog: DomainSubjectResolutionCatalog()
        )
        let directPetAlias = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: "pet",
                relatedEntityId: pet.id.uuidString
            ),
            catalog: DomainSubjectResolutionCatalog()
        )
        let dryStock = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: DomainEntityLinkRegistry.petFoodStock,
                relatedEntityId: "\(pet.id.uuidString):dry"
            ),
            catalog: DomainSubjectResolutionCatalog()
        )
        let wetStock = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: DomainEntityLinkRegistry.petFoodStock,
                relatedEntityId: "\(pet.id.uuidString):wet"
            ),
            catalog: DomainSubjectResolutionCatalog()
        )

        let expected = "\(EntityKind.pet.rawValue):\(pet.id.uuidString)"
        #expect(DomainResolvedSubjectKey(resolution: directPet).rawValue == expected)
        #expect(DomainResolvedSubjectKey(resolution: directPetAlias).rawValue == expected)
        #expect(DomainResolvedSubjectKey(resolution: dryStock).rawValue == expected)
        #expect(DomainResolvedSubjectKey(resolution: wetStock).rawValue == expected)
    }

    @Test func notificationDeliveryPolicyMergesAliasPetSubjectsThroughDomainResolution() {
        let pet = Pet(name: "Momo", species: "cat")
        let scheduledAt = Date(timeIntervalSince1970: 1_800_004_200)
        let firstEvent = Event(
            title: "Water",
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let aliasEvent = Event(
            title: "Water alias",
            eventType: EventType.watering.rawValue,
            relatedEntityType: "pet",
            relatedEntityId: pet.id.uuidString
        )
        let firstReminder = Reminder(event: firstEvent, scheduledAt: scheduledAt)
        let aliasReminder = Reminder(event: aliasEvent, scheduledAt: scheduledAt.addingTimeInterval(10))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let decisions = NotificationDeliveryPolicy.plan(
            reminders: [aliasReminder, firstReminder],
            calendar: calendar
        )
        let deliveredCount = decisions.values.count(where: { decision in
            if case .deliver = decision { return true }
            return false
        })
        let mergedCount = decisions.values.count(where: { decision in
            if case .merged = decision { return true }
            return false
        })
        let stockClassification = NotificationDeliveryPolicy.classification(
            for: Event(
                title: "Food stock",
                relatedEntityType: DomainEntityLinkRegistry.petFoodStock,
                relatedEntityId: "\(pet.id.uuidString):dry"
            )
        )

        #expect(deliveredCount == 1)
        #expect(mergedCount == 1)
        #expect(stockClassification.category == .foodStock)
        #expect(stockClassification.tier == .healthCritical)
    }

    @Test func overdueStatusUsesDomainLinkRolesForMedicationAndPlantLinks() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let scheduledAt = Date(timeIntervalSince1970: 1_800_004_400)
        let now = scheduledAt.addingTimeInterval(86400)
        let pet = Pet(name: "Momo", species: "cat")
        let medication = PetMedication(name: "Drops", pet: pet)
        let plant = Plant(name: "Fern", species: "fern")
        let medicationEvent = Event(
            title: "Dose",
            startDate: scheduledAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
        let plantEvent = Event(
            title: "Water plant",
            startDate: scheduledAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: "plant_watering",
            relatedEntityId: plant.id.uuidString
        )
        let medicationReminder = Reminder(event: medicationEvent, scheduledAt: scheduledAt)
        let plantReminder = Reminder(event: plantEvent, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(medication)
        context.insert(plant)
        context.insert(medicationEvent)
        context.insert(plantEvent)
        context.insert(medicationReminder)
        context.insert(plantReminder)
        try context.save()
        let events = try context.fetch(FetchDescriptor<Event>())

        let medicationWarning = try #require(CarePlanOverdueStatusCalculator.warning(
            for: "medication",
            pet: pet,
            events: events,
            now: now,
            calendar: calendar
        ))
        let plantWarning = try #require(CarePlanOverdueStatusCalculator.plantWarning(
            for: plant,
            events: events,
            now: now,
            calendar: calendar
        ))

        #expect(medicationWarning.actionType == "medication")
        #expect(medicationWarning.reminderId == medicationReminder.id)
        #expect(plantWarning.actionType == "plantWatering")
        #expect(plantWarning.reminderId == plantReminder.id)
    }

    @Test func familyTasksResolveReminderSubjectThroughDomainResolver() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        creator.coconutBalance = 20
        let assignee = Human(name: "Ava")
        let humanOwner = Human(name: "Mira")
        let pet = Pet(name: "Momo", species: "cat")
        let petMedication = PetMedication(name: "Drops", pet: pet)
        let humanMedication = HumanMedication(humanId: humanOwner.id.uuidString, name: "Vitamin")
        let scheduledAt = Date(timeIntervalSince1970: 1_800_004_600)
        let petMedicationEvent = Event(
            title: "Pet dose",
            startDate: scheduledAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: petMedication.id.uuidString
        )
        let humanMedicationEvent = Event(
            title: "Human dose",
            startDate: scheduledAt,
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString
        )
        let petReminder = Reminder(event: petMedicationEvent, scheduledAt: scheduledAt)
        let humanReminder = Reminder(event: humanMedicationEvent, scheduledAt: scheduledAt)
        context.insert(creator)
        context.insert(assignee)
        context.insert(humanOwner)
        context.insert(pet)
        context.insert(petMedication)
        context.insert(humanMedication)
        context.insert(petMedicationEvent)
        context.insert(humanMedicationEvent)
        context.insert(petReminder)
        context.insert(humanReminder)
        try context.save()

        let petTask = try #require(FamilyTaskService.assignReminder(
            petReminder,
            to: assignee,
            by: creator,
            rewardCoconuts: 5,
            context: context
        ))
        let humanTask = try #require(FamilyTaskService.assignReminder(
            humanReminder,
            to: assignee,
            by: creator,
            rewardCoconuts: 5,
            context: context
        ))

        #expect(petTask.relatedPetId == pet.id.uuidString)
        #expect(humanTask.relatedPetId == nil)
        #expect(petMedicationEvent.assigneeId == assignee.id.uuidString)
        #expect(humanMedicationEvent.assigneeId == assignee.id.uuidString)

        FamilyTaskService.submitForReview(humanTask, by: assignee, context: context)

        let reviewLedger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>())
            .first { $0.actionType == "familyTaskSubmitReview" })
        #expect(reviewLedger.subjectKind == CareLedgerSubjectKind.human.rawValue)
        #expect(reviewLedger.subjectId == humanOwner.id.uuidString)
    }

    @Test func familyTaskCreationRequiresFundedPositiveRewardAndDifferentAssignee() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        let assignee = Human(name: "Ava")
        creator.coconutBalance = 60
        context.insert(creator)
        context.insert(assignee)
        try context.save()

        let missingCreator = FamilyTaskService.createHouseholdTask(
            title: "Water plants",
            note: "",
            assignedTo: assignee,
            by: nil,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🌱",
            context: context
        )
        let selfAssigned = FamilyTaskService.createHouseholdTask(
            title: "Water plants",
            note: "",
            assignedTo: creator,
            by: creator,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🌱",
            context: context
        )
        let zeroReward = FamilyTaskService.createHouseholdTask(
            title: "Water plants",
            note: "",
            assignedTo: assignee,
            by: creator,
            rewardCoconuts: 0,
            dueAt: nil,
            emoji: "🌱",
            context: context
        )
        let underfunded = FamilyTaskService.createHouseholdTask(
            title: "Water plants",
            note: "",
            assignedTo: assignee,
            by: creator,
            rewardCoconuts: 61,
            dueAt: nil,
            emoji: "🌱",
            context: context
        )
        let emptyTitle = FamilyTaskService.createHouseholdTask(
            title: "   ",
            note: "",
            assignedTo: assignee,
            by: creator,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🌱",
            context: context
        )
        let created = FamilyTaskService.createHouseholdTask(
            title: "Water plants",
            note: "",
            assignedTo: assignee,
            by: creator,
            rewardCoconuts: 60,
            dueAt: nil,
            emoji: "🌱",
            context: context
        )

        #expect(missingCreator == nil)
        #expect(selfAssigned == nil)
        #expect(zeroReward == nil)
        #expect(underfunded == nil)
        #expect(emptyTitle == nil)
        #expect(created?.kind == .bounty)
        #expect(created?.rewardCoconuts == 60)
        #expect(created?.createdById == creator.id.uuidString)
        #expect(created?.assignedToId == assignee.id.uuidString)
        #expect(CoconutWalletService.balance(for: creator, context: context) == 60)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).count == 1)
    }

    @Test func reminderAssignmentRequiresFundedPositiveRewardAndCreator() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        let replacementCreator = Human(name: "Mira")
        let assignee = Human(name: "Ava")
        creator.coconutBalance = 40
        replacementCreator.coconutBalance = 30
        let event = Event(
            title: "Feed Momo",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            eventType: EventType.task.rawValue
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(creator)
        context.insert(replacementCreator)
        context.insert(assignee)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        #expect(FamilyTaskService.assignReminder(
            reminder,
            to: assignee,
            by: nil,
            rewardCoconuts: 20,
            context: context
        ) == nil)
        #expect(FamilyTaskService.assignReminder(
            reminder,
            to: creator,
            by: creator,
            rewardCoconuts: 20,
            context: context
        ) == nil)
        #expect(FamilyTaskService.assignReminder(
            reminder,
            to: assignee,
            by: creator,
            rewardCoconuts: 0,
            context: context
        ) == nil)
        #expect(FamilyTaskService.assignReminder(
            reminder,
            to: assignee,
            by: creator,
            rewardCoconuts: 41,
            context: context
        ) == nil)

        let task = FamilyTaskService.assignReminder(
            reminder,
            to: assignee,
            by: creator,
            rewardCoconuts: 40,
            context: context
        )

        let removedReward = task.map { task in
            FamilyTaskService.updateTask(
                task,
                title: task.title,
                note: task.note,
                assignedTo: assignee,
                rewardCoconuts: 0,
                dueAt: task.dueAt,
                emoji: task.emoji,
                by: creator,
                context: context
            )
        }

        #expect(task?.rewardCoconuts == 40)
        #expect(task?.createdById == creator.id.uuidString)
        #expect(task?.assignedToId == assignee.id.uuidString)
        #expect(event.assigneeId == assignee.id.uuidString)
        #expect(CoconutWalletService.balance(for: creator, context: context) == 40)
        #expect(removedReward == false)

        let reassigned = FamilyTaskService.assignReminder(
            reminder,
            to: assignee,
            by: replacementCreator,
            rewardCoconuts: 30,
            context: context
        )

        #expect(reassigned?.id == task?.id)
        #expect(reassigned?.createdById == replacementCreator.id.uuidString)
        #expect(reassigned?.createdByName == replacementCreator.name)
        #expect(reassigned?.rewardCoconuts == 30)
        #expect(CoconutWalletService.balance(for: replacementCreator, context: context) == 30)
    }

    @Test func householdTaskUpdateRejectsZeroOrUnderfundedReward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        let assignee = Human(name: "Ava")
        creator.coconutBalance = 80
        context.insert(creator)
        context.insert(assignee)
        try context.save()
        let task = try #require(FamilyTaskService.createHouseholdTask(
            title: "Water plants",
            note: "Original",
            assignedTo: assignee,
            by: creator,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🌱",
            context: context
        ))

        let removedReward = FamilyTaskService.updateTask(
            task,
            title: "No reward",
            note: "Changed",
            assignedTo: assignee,
            rewardCoconuts: 0,
            dueAt: nil,
            emoji: "🧹",
            by: creator,
            context: context
        )
        let underfunded = FamilyTaskService.updateTask(
            task,
            title: "Too expensive",
            note: "Changed",
            assignedTo: assignee,
            rewardCoconuts: 81,
            dueAt: nil,
            emoji: "🧹",
            by: creator,
            context: context
        )
        let reassignedToCreator = FamilyTaskService.updateTask(
            task,
            title: "Self assigned",
            note: "Changed",
            assignedTo: creator,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🧹",
            by: creator,
            context: context
        )
        let updated = FamilyTaskService.updateTask(
            task,
            title: "Mop kitchen",
            note: "Tonight",
            assignedTo: assignee,
            rewardCoconuts: 80,
            dueAt: nil,
            emoji: "🧹",
            by: creator,
            context: context
        )

        #expect(!removedReward)
        #expect(!underfunded)
        #expect(!reassignedToCreator)
        #expect(updated)
        #expect(task.title == "Mop kitchen")
        #expect(task.note == "Tonight")
        #expect(task.rewardCoconuts == 80)
        #expect(task.assignedToId == assignee.id.uuidString)
    }

    @Test func householdTaskEditAndDeleteRequireCreatorActor() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        let assignee = Human(name: "Ava")
        creator.coconutBalance = 80
        context.insert(creator)
        context.insert(assignee)
        try context.save()

        let task = try #require(FamilyTaskService.createHouseholdTask(
            title: "Mop kitchen",
            note: "Tonight",
            assignedTo: assignee,
            by: creator,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🧹",
            context: context
        ))

        #expect(!FamilyTaskService.updateTask(
            task,
            title: "Changed by assignee",
            note: "Unauthorized",
            assignedTo: assignee,
            rewardCoconuts: 20,
            dueAt: nil,
            emoji: "🧹",
            by: assignee,
            context: context
        ))
        #expect(!FamilyTaskService.delete(task, by: assignee, context: context))
        #expect(task.title == "Mop kitchen")
        #expect(FamilyTaskService.delete(task, by: creator, context: context))
    }

    @Test func familyTaskClaimOnlyAcceptsOpenTasks() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        let assignee = Human(name: "Ava")
        let claimant = Human(name: "Mira")
        let assignedTask = FamilyCollaborationTask(
            title: "Assigned",
            kind: .householdTask,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name
        )
        let openTask = FamilyCollaborationTask(
            title: "Open",
            kind: .householdTask,
            createdById: creator.id.uuidString,
            createdByName: creator.name
        )
        context.insert(creator)
        context.insert(assignee)
        context.insert(claimant)
        context.insert(assignedTask)
        context.insert(openTask)
        try context.save()

        let claimedAssignedTask = FamilyTaskService.claim(assignedTask, by: claimant, context: context)
        let claimedOpenTask = FamilyTaskService.claim(openTask, by: claimant, context: context)
        let claimedAgain = FamilyTaskService.claim(openTask, by: assignee, context: context)

        #expect(!claimedAssignedTask)
        #expect(assignedTask.status == .active)
        #expect(assignedTask.claimedById == nil)
        #expect(claimedOpenTask)
        #expect(!claimedAgain)
        #expect(openTask.status == .claimed)
        #expect(openTask.claimedById == claimant.id.uuidString)
    }

    @Test func familyTaskCompletionOnlyAcceptsAssigneeOrClaimant() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let creator = Human(name: "Guan")
        let assignee = Human(name: "Ava")
        let outsider = Human(name: "Mira")
        creator.coconutBalance = 100
        let assignedTask = FamilyCollaborationTask(
            title: "Assigned",
            kind: .householdTask,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name
        )
        let rewardedTask = FamilyCollaborationTask(
            title: "Rewarded",
            kind: .bounty,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 20
        )
        let claimedTask = FamilyCollaborationTask(
            title: "Claimed",
            kind: .bounty,
            status: .claimed,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            rewardCoconuts: 20
        )
        claimedTask.claimedById = assignee.id.uuidString
        claimedTask.claimedByName = assignee.name
        context.insert(creator)
        context.insert(assignee)
        context.insert(outsider)
        context.insert(assignedTask)
        context.insert(rewardedTask)
        context.insert(claimedTask)
        try context.save()

        #expect(!FamilyTaskService.complete(assignedTask, by: outsider, context: context))
        #expect(assignedTask.status == .active)
        #expect(FamilyTaskService.complete(assignedTask, by: assignee, context: context))
        #expect(assignedTask.status == .completed)

        #expect(!FamilyTaskService.submitForReview(rewardedTask, by: outsider, context: context))
        #expect(rewardedTask.status == .active)
        #expect(FamilyTaskService.submitForReview(rewardedTask, by: assignee, context: context))
        #expect(rewardedTask.status == .pendingReview)

        #expect(!FamilyTaskService.submitForReview(claimedTask, by: outsider, context: context))
        #expect(FamilyTaskService.submitForReview(claimedTask, by: assignee, context: context))
        #expect(claimedTask.status == .pendingReview)
    }

    @Test func memberDeletionResultsUseDomainResolverForIndirectScheduleLinks() throws {
        let petContainer = try makeInMemoryContainer()
        let petContext = petContainer.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let petMedication = PetMedication(name: "Drops", pet: pet)
        let petMedicationEvent = Event(
            title: "Pet dose",
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: petMedication.id.uuidString
        )
        petContext.insert(pet)
        petContext.insert(petMedication)
        petContext.insert(petMedicationEvent)
        try petContext.save()

        let petResult = MemberDeletionCommandService.deletePet(pet, context: petContext)

        #expect(petResult.removedRelatedEventIDs.contains(petMedicationEvent.id))
        #expect(try petContext.fetch(FetchDescriptor<Event>()).isEmpty)

        let humanContainer = try makeInMemoryContainer()
        let humanContext = humanContainer.mainContext
        let human = Human(name: "Mira")
        let survivor = Human(name: "Ava")
        let humanMedication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin")
        let humanMedicationEvent = Event(
            title: "Human dose",
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString
        )
        humanContext.insert(human)
        humanContext.insert(survivor)
        humanContext.insert(humanMedication)
        humanContext.insert(humanMedicationEvent)
        try humanContext.save()

        let humanResult = MemberDeletionCommandService.deleteHuman(
            human,
            activeHumanID: survivor.id.uuidString,
            context: humanContext
        )

        #expect(humanResult.removedRelatedEventIDs.contains(humanMedicationEvent.id))
        #expect(try humanContext.fetch(FetchDescriptor<Event>()).isEmpty)
    }

    @Test func domainPolicyAuthorizerRequiresRegisteredTaxonomyForNonEmptyLinks() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        try context.save()

        let knownPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .schedule,
                source: .userCommand,
                subjectRequest: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: pet.id.uuidString
                ),
                writeKind: .care
            ),
            context: context
        )
        let missingPetResolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: UUID().uuidString
            ),
            context: context
        )
        let unknownPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .schedule,
                source: .userCommand,
                subjectRequest: DomainSubjectResolutionRequest(
                    relatedEntityType: "pet_vaccine_plan",
                    relatedEntityId: pet.id.uuidString
                ),
                writeKind: .care
            ),
            context: context
        )
        let unscopedPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .schedule,
                source: .userCommand,
                subjectRequest: DomainSubjectResolutionRequest(),
                writeKind: .memorial
            ),
            context: context
        )

        #expect(knownPlan?.subject.owner == .pet(pet.id))
        #expect(knownPlan?.writesContent == true)
        #expect(missingPetResolution.owner == nil)
        #expect(missingPetResolution.unresolvedOwner)
        #expect(unknownPlan == nil)
        #expect(unscopedPlan?.subject.role == .unscoped)
        #expect(unscopedPlan?.writesContent == true)
        #expect(unscopedPlan?.allowsDerivedEffects == false)
    }

    @Test func domainPolicyAuthorizerCarriesLifecycleDispositionInPlan() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        try context.save()

        let request = DomainMutationAuthorizationRequest(
            scope: .memberContent,
            source: .userCommand,
            subjectRequest: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            ),
            writeKind: .care
        )
        #expect(DomainPolicyAuthorizer.authorize(request, context: context) != nil)

        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_003_600)

        let deniedCare = DomainPolicyAuthorizer.authorize(request, context: context)
        let memorialPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .memberContent,
                source: .userCommand,
                subjectRequest: request.subjectRequest,
                writeKind: .memorial
            ),
            context: context
        )

        #expect(deniedCare == nil)
        #expect(memorialPlan?.writesContent == true)
        #expect(memorialPlan?.allowsCareFactWrite == false)
        #expect(memorialPlan?.allowsDerivedEffects == false)
        #expect(memorialPlan?.allowsEconomyDerivation == false)
    }

    @Test func scheduleAuthorizerConsumesGenericMutationPlanAndDropsInvalidAssignee() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        try context.save()

        let intent = DomainScheduleCreateIntent(
            title: "Care",
            startDate: Date(timeIntervalSince1970: 1_800_003_700),
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            assigneeId: "not-a-uuid",
            writeKind: .care
        )
        let deniedGenericPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .schedule,
                source: .userCommand,
                subjectRequest: DomainSubjectResolutionRequest(
                    link: intent.relatedLink,
                    assigneeId: intent.assigneeId
                ),
                writeKind: .care,
                unresolvedAssigneePolicy: .deny
            ),
            context: context
        )
        let schedulePlan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context)
        let missingHumanId = UUID().uuidString
        let missingAssigneeIntent = DomainScheduleCreateIntent(
            title: "Care",
            startDate: Date(timeIntervalSince1970: 1_800_003_701),
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            assigneeId: missingHumanId,
            writeKind: .care
        )
        let deniedMissingHumanPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .schedule,
                source: .userCommand,
                subjectRequest: DomainSubjectResolutionRequest(
                    link: missingAssigneeIntent.relatedLink,
                    assigneeId: missingAssigneeIntent.assigneeId
                ),
                writeKind: .care,
                unresolvedAssigneePolicy: .deny
            ),
            context: context
        )
        let missingAssigneeSchedulePlan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: missingAssigneeIntent,
            context: context
        )

        #expect(deniedGenericPlan == nil)
        #expect(schedulePlan?.mutationPlan.scope == .schedule)
        #expect(schedulePlan?.mutationPlan.source == .userCommand)
        #expect(schedulePlan?.intent.assigneeId == nil)
        #expect(schedulePlan?.resolution.owner == .pet(pet.id))
        #expect(schedulePlan?.resolution.assignee == nil)
        #expect(deniedMissingHumanPlan == nil)
        #expect(missingAssigneeSchedulePlan?.intent.assigneeId == nil)
        #expect(missingAssigneeSchedulePlan?.resolution.assignee == nil)
    }

    @Test func careFactWritePolicyConsumesGenericMutationPlanWithoutConflatingActor() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let inactiveExecutor = Human(name: "Ava")
        inactiveExecutor.passedAwayDate = Date(timeIntervalSince1970: 1_800_003_750)
        context.insert(pet)
        context.insert(inactiveExecutor)
        try context.save()

        let plan = CareFactWritePolicy.authorizePetCareFact(pet: pet, context: context)
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: Date(timeIntervalSince1970: 1_800_003_760),
            executorId: inactiveExecutor.id.uuidString,
            context: context
        )

        #expect(plan?.scope == .careFact)
        #expect(plan?.subject.owner == .pet(pet.id))
        #expect(plan?.subject.assignee == nil)
        #expect(disposition == .active)

        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_003_770)

        #expect(CareFactWritePolicy.authorizePetCareFact(pet: pet, context: context) == nil)
        #expect(CareFactWritePolicy.disposition(
            pet: pet,
            date: Date(timeIntervalSince1970: 1_800_003_780),
            executorId: nil,
            context: context
        ) == .noOp)
    }

    @Test func calendarPlanRevisionConsumesTypedAffectedSubjectIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        context.insert(pet)
        context.insert(insurance)
        try context.save()

        let input = CalendarEventPlanCommandInput(
            title: "Insurance",
            startDate: Date(timeIntervalSince1970: 1_800_003_790),
            isAllDay: false,
            eventType: .insurancePremium,
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString,
            recurrenceDays: 0,
            recurrenceEndDate: nil,
            reminderLeadMinutes: 15,
            assigneeId: nil
        )
        let result = try #require(try CalendarEventPlanCommandService.createEvent(
            input: input,
            context: context,
            scheduleNotifications: false
        ))
        let center = ReadModelRevisionCenter()
        let revisions = SharedDomainRevisionPublisher(center: center)

        revisions.publishCalendarEventPlan(result, note: "test.calendar.indirect")

        let mutation = try #require(center.lastMutation)
        #expect(result.affectedSubjectIDs.contains(pet.id))
        #expect(result.affectedSubjectIDs.contains(insurance.id))
        #expect(mutation.affectedEntityIDs.contains(pet.id))
        #expect(mutation.affectedEntityIDs.contains(insurance.id))
        #expect(mutation.affectedEntityIDs.contains(result.eventID))
        for reminderID in result.reminderIDs {
            #expect(mutation.affectedEntityIDs.contains(reminderID))
        }
    }

    @Test func calendarCompletionAndReminderRevisionsConsumeTypedAffectedSubjectIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        let event = Event(
            title: "Insurance",
            startDate: Date(timeIntervalSince1970: 1_800_003_800),
            eventType: EventType.insurancePremium.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(pet)
        context.insert(insurance)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let completion = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: event.startDate,
            pets: [pet],
            context: context,
            executorId: nil
        )
        let center = ReadModelRevisionCenter()
        let revisions = SharedDomainRevisionPublisher(center: center)
        revisions.publishCalendarEventCompletion(completion, note: "test.calendar.complete")
        var mutation = try #require(center.lastMutation)

        #expect(completion.affectedSubjectIDs.contains(pet.id))
        #expect(completion.affectedSubjectIDs.contains(insurance.id))
        #expect(mutation.affectedEntityIDs.contains(event.id))
        #expect(mutation.affectedEntityIDs.contains(pet.id))
        #expect(mutation.affectedEntityIDs.contains(insurance.id))

        let reminderResult = ReminderCommandExecutor(context: context, revisionCenter: center)
            .complete(reminder, by: nil, note: "test.reminder.complete")
        mutation = try #require(center.lastMutation)

        #expect(reminderResult.affectedSubjectIDs.contains(pet.id))
        #expect(reminderResult.affectedSubjectIDs.contains(insurance.id))
        #expect(mutation.affectedEntityIDs.contains(reminder.id))
        #expect(mutation.affectedEntityIDs.contains(event.id))
        #expect(mutation.affectedEntityIDs.contains(pet.id))
        #expect(mutation.affectedEntityIDs.contains(insurance.id))
    }

    @Test func careLedgerSubjectResolutionUsesDomainResolver() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Ava")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        context.insert(pet)
        context.insert(human)
        context.insert(insurance)
        try context.save()

        let insuranceEvent = Event(
            title: "Insurance",
            startDate: Date(timeIntervalSince1970: 1_800_003_800),
            eventType: EventType.insurancePremium.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        )
        let assigneeOnlyEvent = Event(title: "Assigned household task")
        assigneeOnlyEvent.assigneeId = human.id.uuidString
        let legacyUnknownEvent = Event(
            title: "Legacy",
            relatedEntityType: "legacy_custom",
            relatedEntityId: "legacy-id"
        )

        let insuranceSubject = CareLedgerService.subjectInfo(from: insuranceEvent, context: context)
        let assigneeSubject = CareLedgerService.subjectInfo(from: assigneeOnlyEvent, context: context)
        let legacySubject = CareLedgerService.subjectInfo(from: legacyUnknownEvent, context: context)
        let emptySubject = CareLedgerService.subjectInfo(from: nil, context: context)

        #expect(insuranceSubject.kind == .pet)
        #expect(insuranceSubject.id == pet.id.uuidString)
        #expect(assigneeSubject.kind == .human)
        #expect(assigneeSubject.id == human.id.uuidString)
        #expect(legacySubject.kind == .unknown)
        #expect(legacySubject.id == "legacy-id")
        #expect(emptySubject.kind == .system)
        #expect(emptySubject.id == nil)
    }

    @Test func careLedgerWritesUseResolvedIndirectScheduleSubject() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        let event = Event(
            title: "Insurance",
            startDate: Date(timeIntervalSince1970: 1_800_003_900),
            eventType: EventType.insurancePremium.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(pet)
        context.insert(insurance)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "scheduleSuccess",
            actorId: nil,
            source: .service,
            context: context
        )
        _ = CareLedgerService().recordEventCompletionReward(
            event: event,
            occurrenceDate: event.startDate,
            actorId: nil,
            coconutDelta: 1,
            occurredAt: Date(timeIntervalSince1970: 1_800_003_901),
            context: context
        )

        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let reminderLedger = ledgers.first { $0.actionType == "scheduleSuccess" }
        let rewardLedger = ledgers.first { $0.actionType == "eventCompletionReward" }

        #expect(reminderLedger?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(reminderLedger?.subjectId == pet.id.uuidString)
        #expect(rewardLedger?.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(rewardLedger?.subjectId == pet.id.uuidString)
    }

    @Test func rewardAutoCompleteUsesResolvedIndirectPetScheduleSubject() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "cat")
        let medication = PetMedication(name: "Drops", pet: pet)
        let otherMedication = PetMedication(name: "Vitamin", pet: otherPet)
        let scheduledAt = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let medicationEvent = Event(
            title: "用药 Drops", // localization-audit: allow historical event fixture title
            startDate: scheduledAt,
            eventType: EventType.medication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
        let otherMedicationEvent = Event(
            title: "用药 Vitamin", // localization-audit: allow historical event fixture title
            startDate: scheduledAt,
            eventType: EventType.medication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: otherMedication.id.uuidString
        )
        let medicationReminder = Reminder(event: medicationEvent, scheduledAt: scheduledAt)
        let otherMedicationReminder = Reminder(event: otherMedicationEvent, scheduledAt: scheduledAt)
        context.insert(pet)
        context.insert(otherPet)
        context.insert(medication)
        context.insert(otherMedication)
        context.insert(medicationEvent)
        context.insert(otherMedicationEvent)
        context.insert(medicationReminder)
        context.insert(otherMedicationReminder)
        try context.save()

        QuestManager().autoCompleteReminders(petId: pet.id, careKeyword: "用药", context: context)

        #expect(medicationReminder.statusEnum == .completed)
        #expect(otherMedicationReminder.statusEnum == .pending)
    }

    @Test func reminderDeepLinkUsesResolvedIndirectScheduleSubject() {
        let pet = Pet(name: "Momo", species: "cat")
        let human = Human(name: "Ava")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        let humanMedication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin")
        let insuranceEvent = Event(
            title: "Insurance",
            eventType: EventType.insurancePremium.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        )
        let humanMedicationPayload = OhanaReminderRoutePayload(userInfo: [
            "relatedEntityType": DomainEntityLinkRegistry.humanMedicationPlan,
            "relatedEntityId": humanMedication.id.uuidString
        ])!

        let eventDestination = FocusHomeReminderDeepLinkRouter.destination(
            for: insuranceEvent,
            pets: [pet],
            humans: [human],
            plants: [],
            humanMedications: [humanMedication]
        )
        let fallbackDestination = FocusHomeReminderDeepLinkRouter.destination(
            for: humanMedicationPayload,
            reminders: [],
            events: [],
            pets: [pet],
            humans: [human],
            plants: [],
            humanMedications: [humanMedication]
        )

        if case let .functionMenu(.petInsurance(persistentID)) = eventDestination {
            #expect(persistentID == pet.persistentModelID)
        } else {
            Issue.record("Expected pet insurance destination for indirect insurance event")
        }

        if case let .humanDetail(routedHuman) = fallbackDestination {
            #expect(routedHuman.id == human.id)
        } else {
            Issue.record("Expected human detail destination for indirect human medication payload")
        }
    }

    @Test func deceasedPetCannotWriteWalkGoalOrSummary() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_115)
        pet.weeklyWalkGoalKm = 2
        let walk = PetWalkLog(startDate: Date(timeIntervalSince1970: 1_800_001_500), pet: pet)
        context.insert(pet)
        context.insert(walk)
        try context.save()

        let goal = PetWalkCommandService.saveWeeklyGoal(8, for: pet, context: context)
        let summary = PetWalkCommandService.saveSummary(
            for: walk,
            pet: pet,
            moodRating: 5,
            notes: "still active",
            context: context
        )

        #expect(goal.didWrite == false)
        #expect(goal.goalKm == 2)
        #expect(summary.didWrite == false)
        #expect(walk.moodRating == 0)
        #expect(walk.behaviorNotes == nil)
        #expect(try context.fetch(FetchDescriptor<CloudSyncRecordState>()).isEmpty)
    }

    @Test func deceasedFeatureHubsExposeOnlyMemorialSafeDestinations() {
        #expect(PetAllFeatureDestination.moments.isAvailableInMemorialMode)
        #expect(PetAllFeatureDestination.documents.isAvailableInMemorialMode)
        #expect(PetAllFeatureDestination.retention.isAvailableInMemorialMode)
        #expect(!PetAllFeatureDestination.food.isAvailableInMemorialMode)
        #expect(!PetAllFeatureDestination.health.isAvailableInMemorialMode)
        #expect(!PetAllFeatureDestination.walks.isAvailableInMemorialMode)
        #expect(!PetAllFeatureDestination.bondVault.isAvailableInMemorialMode)

        #expect(HumanAllFeatureDestination.basicInfo.isAvailableInMemorialMode)
        #expect(HumanAllFeatureDestination.notes.isAvailableInMemorialMode)
        #expect(!HumanAllFeatureDestination.medication.isAvailableInMemorialMode)
        #expect(!HumanAllFeatureDestination.weight.isAvailableInMemorialMode)
        #expect(!HumanAllFeatureDestination.expense.isAvailableInMemorialMode)
        #expect(!HumanAllFeatureDestination.wishlist.isAvailableInMemorialMode)
    }

    @Test func memorialSurfacesDoNotUseRecycleBinOrPendingDeleteLanguage() throws {
        let rootURL = repositoryRootURL()
        let memorialSurfacePaths = [
            "Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift",
            "Ohana/Features/Members/Views/PetBasicInfoDetailView+MemorialDanger.swift",
            "Ohana/Features/Members/Views/PetBasicInfoDangerZone.swift",
            "Ohana/Features/Members/Views/HumanAllFeaturesSheet.swift",
            "Ohana/Features/Members/Views/PetAllFeaturesSheet.swift",
            "Ohana/Features/Members/HumanDetailSheetRouteContainer.swift",
            "Ohana/Features/Members/PetDetailSheetRouteContainer.swift"
        ]
        let disallowedTerms = [
            "回收",
            "回收站",
            "待删除",
            "30 天",
            "30天",
            "30 days",
            "recycle",
            "pending delete",
            "pending deletion"
        ]

        for path in memorialSurfacePaths {
            let text = try source(path, rootURL: rootURL)
            for term in disallowedTerms where text.localizedCaseInsensitiveContains(term) {
                Issue.record("Memorial surface \(path) must not use recycle-bin or pending-delete language: \(term)")
            }
        }
    }

    @Test func petMemorialConfirmationExplainsActiveReminderExitWithoutDeletionCopy() throws {
        let source = try source(
            "Ohana/Features/Members/Views/PetBasicInfoDetailView+MemorialDanger.swift",
            rootURL: repositoryRootURL()
        )
        let alertSection = try #require(
            source.components(separatedBy: ".alert(l.tr(zh: \"确认标记离世\"").dropFirst().first?
                .components(separatedBy: "// MARK: - Danger Zone").first
        )

        #expect(alertSection.contains("未来照护安排退出活跃提醒"))
        #expect(alertSection.contains("原有数据会保留"))
        #expect(alertSection.contains("此操作可撤销"))

        for term in ["删除未来提醒", "删除未来事件", "删除提醒", "删除事件"] {
            #expect(!alertSection.localizedCaseInsensitiveContains(term))
        }
    }

    @Test func petAllFeaturesUsesRouteScopedActivitySummaryInsteadOfPetRelationshipCareLogs() throws {
        let rootURL = repositoryRootURL()
        let sheetSource = try source("Ohana/Features/Members/Views/PetAllFeaturesSheet.swift", rootURL: rootURL)
        let routeSource = try source("Ohana/Features/Members/PetDetailSheetRouteContainer.swift", rootURL: rootURL)
        let actorSource = try source("Ohana/Features/Members/PetAllFeaturesActivitySummaryActor.swift", rootURL: rootURL)
        let sheetViewSource = try #require(sheetSource.components(separatedBy: "enum ArchiveMemoryNextStepKind").first)

        #expect(!sheetViewSource.contains("pet.careLogs"))
        #expect(!sheetViewSource.contains("pet.pottyLogs"))
        #expect(!sheetViewSource.contains("pet.walkLogs"))
        #expect(!sheetViewSource.contains("pet.weightLogs"))
        #expect(!sheetViewSource.contains("pet.expenseLogs"))
        #expect(!sheetViewSource.contains("pet.healthLogs"))
        #expect(!sheetViewSource.contains("pet.photoLogs"))
        #expect(!sheetViewSource.contains("pet.milestones"))
        #expect(!sheetViewSource.contains("activeCareLogs"))
        #expect(!sheetViewSource.contains("activePottyLogs"))
        #expect(!sheetViewSource.contains("activeWalkLogs"))
        #expect(!sheetViewSource.contains("activeWeightLogs"))
        #expect(!sheetViewSource.contains("activeExpenseLogs"))
        #expect(!sheetViewSource.contains("activeHealthLogs"))
        #expect(!sheetViewSource.contains("activePhotoLogs"))
        #expect(!sheetViewSource.contains("activeMilestones"))
        #expect(!sheetSource.contains("FetchDescriptor<PetCareLog>"))
        #expect(!sheetSource.contains("FetchDescriptor<PetPottyLog>"))
        #expect(!sheetSource.contains("FetchDescriptor<PetWalkLog>"))
        #expect(sheetSource.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(sheetSource.contains("ArchiveMemorySnapshot(pet: pet, activitySummary: activitySummary)"))
        #expect(sheetSource.contains("struct PetAllFeaturesActivitySummary"))
        #expect(sheetSource.contains("try context.fetchCount"))
        #expect(routeSource.contains("@State private var allFeaturesActivitySummary"))
        #expect(routeSource.contains("PetAllFeaturesActivitySummaryActor(modelContainer: container)"))
        #expect(!routeSource.contains("PetAllFeaturesActivitySummary.load(petID: petID, context: modelContext)"))
        #expect(routeSource.contains("OhanaFrameScheduler.waitAfterNextFrame"))
        #expect(actorSource.contains("@ModelActor"))
        #expect(actorSource.contains("PetAllFeaturesActivitySummary.load("))
    }

    @Test func petAllFeaturesActivitySummaryUsesLedgerAndRouteScopedCounts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 12)))
        let todayStart = calendar.startOfDay(for: now)
        let pet = Pet(name: "Momo", species: "狗")
        let otherPet = Pet(name: "Nori", species: "猫")
        context.insert(pet)
        context.insert(otherPet)

        context.insert(PetCareLog(date: now, type: .feeding, amountGrams: 999, pet: pet))
        context.insert(PetPottyLog(date: now, type: .pee, pet: pet))
        context.insert(PetWalkLog(startDate: now, pet: pet))

        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(3600),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: 42
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(4200),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(-86400),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.watering.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(5000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .potty,
            actionType: PottyType.pee.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(6000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .walk,
            actionType: "walk",
            amountValue: 1200
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(-2 * 86400),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .walk,
            actionType: "walk",
            amountValue: 800
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(7000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: HealthLogType.checkup.rawValue
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(-7000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(8000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.8
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(9000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.food.rawValue,
            amountValue: 20
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(10000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.treats.rawValue,
            amountValue: 30
        ))
        context.insert(CareLedgerEvent(
            occurredAt: todayStart.addingTimeInterval(11000),
            actorKind: .human,
            actorId: "human-a",
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        ))

        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), pet: pet))
        context.insert(PetMilestone(title: "First hike", pet: pet))
        context.insert(PetDocument(title: "Vaccine", category: .vaccine, pet: pet))
        context.insert(PetDocument(title: "Passport", category: .other, pet: pet))
        context.insert(PetInsurance(companyName: "Ohana Care", pet: pet))
        context.insert(PetMedication(name: "Active", startDate: todayStart, pet: pet))
        let inactiveMedication = PetMedication(name: "Inactive", startDate: todayStart, pet: pet)
        inactiveMedication.isActive = false
        context.insert(inactiveMedication)
        try context.save()

        let summary = PetAllFeaturesActivitySummary.load(petID: pet.id, context: context, now: now)

        #expect(summary.todayFeedCount == 1)
        #expect(summary.todayNonFeedingCareCount == 1)
        #expect(summary.totalNonFeedingCareCount == 2)
        #expect(summary.todayPottyCount == 1)
        #expect(summary.todayWalkCount == 1)
        #expect(summary.totalWalkCount == 2)
        #expect(summary.weekWalkDistanceMeters == 2000)
        #expect(summary.healthCount == 1)
        #expect(summary.weightCount == 2)
        #expect(summary.latestWeightKg == 4.8)
        #expect(summary.expenseCount == 2)
        #expect(summary.expenseTotal == 50)
        #expect(summary.photoCount == 1)
        #expect(summary.milestoneCount == 1)
        #expect(summary.documentCount == 2)
        #expect(summary.protectionDocumentCount == 1)
        #expect(summary.insuranceCount == 1)
        #expect(summary.medicationCount == 2)
        #expect(summary.activeMedicationCount == 1)
    }

    @Test func featureAggregateViewDoesNotCarryLegacyCareRelationshipSubtitles() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/Features/FunctionMenu/Views/FeatureAggregateView.swift", rootURL: rootURL)

        #expect(!source.contains("pet.careLogs"))
        #expect(!source.contains("pet.pottyLogs"))
        #expect(!source.contains("pet.walkLogs"))
        #expect(!source.contains("pet.hygieneLogs"))
        #expect(!source.contains("pet.expenseLogs"))
        #expect(!source.contains("pet.weightLogs"))
        #expect(source.contains("case .health, .medications, .food, .hygiene, .walks, .potty, .retention, .weight, .expense:"))
    }

    @Test func familyActivityStripUsesLedgerEntriesInsteadOfPetRelationshipLogs() throws {
        let rootURL = repositoryRootURL()
        let stripSource = try source("Ohana/Features/FamilyTasks/Views/FamilyActivityStripView.swift", rootURL: rootURL)
        let routeSource = try source("Ohana/Features/FamilyTasks/FamilyActivityStripRouteContainer.swift", rootURL: rootURL)

        #expect(!stripSource.contains("pet.careLogs"))
        #expect(!stripSource.contains("pet.pottyLogs"))
        #expect(!stripSource.contains("pet.walkLogs"))
        #expect(!stripSource.contains("pet.expenseLogs"))
        #expect(!routeSource.contains("@Query private var ledgerEvents"))
        #expect(routeSource.contains("OhanaFrameScheduler.runAfterNextFrame"))
        #expect(routeSource.contains("try context.fetch(descriptor)"))
        #expect(routeSource.contains("FamilyActivityEntry.entries("))
    }

    @Test func familyActivityEntriesProjectTodayLedgerEventsAndSharedWalkExecutors() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 12)))
        let today = calendar.startOfDay(for: now)
        let petID = UUID()
        let otherPetID = UUID()
        let humanA = UUID().uuidString
        let humanB = UUID().uuidString
        let humanC = UUID().uuidString

        let care = CareLedgerEvent(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            occurredAt: today.addingTimeInterval(3600),
            actorKind: .human,
            actorId: humanA,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        )
        let walk = CareLedgerEvent(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            occurredAt: today.addingTimeInterval(7200),
            actorKind: .human,
            actorId: humanB,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .walk,
            actionType: "walk",
            metadataJSON: "{\"executorIds\":[\"\(humanB)\",\"\(humanC)\"]}"
        )
        let previousDay = CareLedgerEvent(
            occurredAt: today.addingTimeInterval(-60),
            actorKind: .human,
            actorId: humanA,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .potty,
            actionType: PottyType.pee.rawValue
        )
        let otherPet = CareLedgerEvent(
            occurredAt: today.addingTimeInterval(3900),
            actorKind: .human,
            actorId: humanA,
            subjectKind: .pet,
            subjectId: otherPetID.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.food.rawValue
        )

        let entries = FamilyActivityEntry.entries(
            from: [care, walk, previousDay, otherPet],
            petID: petID,
            calendar: calendar,
            now: now
        )

        #expect(entries.compactMap(\.executorId) == [humanA, humanB, humanC])
        #expect(entries.map(\.dedupKey) == [
            "\(humanA)_care_\(CareType.feeding.rawValue)",
            "\(humanB)_walk",
            "\(humanC)_walk"
        ])
        #expect(entries.map(\.iconName) == ["fork.knife", "figure.walk", "figure.walk"])
    }

    @Test func familyTaskActivitySurfacesUseLedgerEntriesInsteadOfPetRelationshipLogs() throws {
        let rootURL = repositoryRootURL()
        let bountySource = try source("Ohana/Features/FamilyTasks/Views/BountyBoardView.swift", rootURL: rootURL)
        let bountyRouteSource = try source("Ohana/Features/FamilyTasks/BountyBoardDataContainer.swift", rootURL: rootURL)
        let collaborationSource = try source("Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView.swift", rootURL: rootURL)
        let collaborationActivitySource = try source("Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView+Activity.swift", rootURL: rootURL)
        let crewRouteSource = try source("Ohana/Features/CrewRoster/CrewRosterRouteContainer.swift", rootURL: rootURL)

        for source in [bountySource, collaborationSource, collaborationActivitySource] {
            #expect(!source.contains("pet.careLogs"))
            #expect(!source.contains("pet.pottyLogs"))
            #expect(!source.contains("pet.walkLogs"))
            #expect(!source.contains("pet.expenseLogs"))
        }
        #expect(bountySource.contains("careLedgerEntries: [FamilyCareLedgerEntry]"))
        #expect(bountyRouteSource.contains("FamilyCareLedgerEntry.fetchPetEntries"))
        #expect(crewRouteSource.contains("careLedgerEntries: FamilyCareLedgerEntry.fetchPetEntries"))
        #expect(collaborationSource.contains("careLedgerEntries.compactMap"))
        #expect(collaborationActivitySource.contains("careLedgerEntries.contains"))
    }

    @Test func crewRosterUsesRouteScopedPetSummariesInsteadOfPetArchiveRelationships() throws {
        let rootURL = repositoryRootURL()
        let routeSource = try source("Ohana/Features/CrewRoster/CrewRosterRouteContainer.swift", rootURL: rootURL)
        let overlaySource = try source("Ohana/Features/CrewRoster/Views/CrewRosterOverlay.swift", rootURL: rootURL)
        let editorsSource = try source("Ohana/Features/CrewRoster/Views/CrewRosterOverlayEditors.swift", rootURL: rootURL)

        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: "Ohana/Features/CrewRoster/Views/CrewRosterExpandedMemberOverlay.swift").path
        ))
        #expect(!overlaySource.contains("pet.documents.count"))
        #expect(!overlaySource.contains("pet.weightLogs"))
        #expect(!editorsSource.contains("pet.documents.count"))
        #expect(!editorsSource.contains("pet.weightLogs"))
        #expect(routeSource.contains("struct CrewRosterPetSummary"))
        #expect(routeSource.contains("FetchDescriptor<PetDocument>"))
        #expect(routeSource.contains("context.fetchCount(descriptor)"))
        #expect(overlaySource.contains("var petSummaries: [UUID: CrewRosterPetSummary]"))
        #expect(editorsSource.contains("let petSummary: CrewRosterPetSummary"))
        #expect(editorsSource.contains("@State private var avatarImageRevision"))
        #expect(editorsSource.contains("avatarImageData: editableAvatarImageData"))
        #expect(editorsSource.contains("avatarImageRevision &+="))
        #expect(!editorsSource.contains("avatarImageData?.count"))
    }

    @Test func crewRosterPetSummaryCountsPetScopedDocuments() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        context.insert(pet)
        context.insert(otherPet)
        context.insert(PetDocument(title: "Passport", category: .passport, pet: pet))
        context.insert(PetDocument(title: "Vaccine", category: .vaccine, pet: pet))
        context.insert(PetDocument(title: "Other", category: .other, pet: otherPet))
        try context.save()

        let summaries = CrewRosterPetSummary.load(pets: [pet, otherPet], context: context)

        #expect(summaries[pet.id]?.documentCount == 2)
        #expect(summaries[otherPet.id]?.documentCount == 1)
    }

    @Test func petProfileCardsUseRouteSummariesInsteadOfPetRelationshipHealthReads() throws {
        let rootURL = repositoryRootURL()
        let basicSource = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView.swift", rootURL: rootURL)
        let editSource = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView+Edit.swift", rootURL: rootURL)
        let humanBasicSource = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift", rootURL: rootURL)
        let humanEditSource = try source("Ohana/Features/Members/Views/EditHumanSheet.swift", rootURL: rootURL)
        let memberCreationSource = try source("Ohana/Features/Members/MemberCardCreationSupport.swift", rootURL: rootURL)
        let healthSource = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView+HealthSummary.swift", rootURL: rootURL)
        let sitterSource = try source("Ohana/Features/Members/Views/SitterCardPreviewSheet.swift", rootURL: rootURL)

        for source in [healthSource, sitterSource] {
            #expect(!source.contains("pet.healthLogs"))
            #expect(!source.contains("pet.medications"))
            #expect(!source.contains("pet.insurances"))
            #expect(!source.contains("pet.symptomLogs"))
            #expect(!source.contains("pet.weightLogs"))
        }
        #expect(basicSource.contains("@State var healthSummary = PetBasicInfoHealthSummary.empty"))
        #expect(basicSource.contains("scheduleHealthSummaryLoad()"))
        #expect(healthSource.contains("struct PetBasicInfoHealthSummary"))
        #expect(healthSource.contains("FetchDescriptor<PetHealthLog>"))
        #expect(healthSource.contains("FetchDescriptor<PetMedication>"))
        #expect(healthSource.contains("FetchDescriptor<SymptomLog>"))
        #expect(healthSource.contains("FetchDescriptor<PetInsurance>"))
        #expect(healthSource.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(healthSource.contains("OhanaFrameScheduler.runAfterNextFrame"))
        #expect(!healthSource.contains("var vaccineSummaryText: String ="))
        #expect(!healthSource.contains("var activeMedicationSummaryText: String ="))
        #expect(!healthSource.contains("var recentSymptomSummaryText: String ="))
        #expect(!healthSource.contains("var insuranceSummaryText: String ="))
        #expect(!healthSource.contains("var recentWeightSummaryText: String ="))
        #expect(healthSource.contains("localizedVaccineSummary(l:"))
        #expect(healthSource.contains("localizedMedicationSummary(l:"))
        let legacyEmptyValue = "\u{672A}\u{586B}\u{5199}"
        #expect(!editSource.contains("selection.wrappedValue.isEmpty ? \"\(legacyEmptyValue)\""))
        #expect(!editSource.contains("$0 == \"\(legacyEmptyValue)\" ? \"\" : $0"))
        #expect(editSource.contains("Text(option.isEmpty ? petProfileEmptyValue : option).tag(option)"))
        #expect(!editSource.contains("ForEach(speciesOptions, id: \\.self) { Text($0) }"))
        #expect(editSource.contains("Text(Pet.localizedSpeciesName(species, l: l)).tag(species)"))
        #expect(!humanBasicSource.contains("selection.wrappedValue.isEmpty ? \"\(legacyEmptyValue)\""))
        #expect(!humanBasicSource.contains("$0 == \"\(legacyEmptyValue)\" ? \"\" : $0"))
        #expect(humanBasicSource.contains("Text(localizedOptionTitle(option)).tag(option)"))
        #expect(humanBasicSource.contains("option.isEmpty ? localizedEmptyValue : option"))
        #expect(!humanBasicSource.contains("eGender = human.genderRaw.isEmpty ? \"不透露\" : human.genderRaw"))
        #expect(!humanEditSource.contains("@State private var gender: String = \"不透露\""))
        #expect(!humanEditSource.contains("gender = human.genderRaw.isEmpty ? \"不透露\" : human.genderRaw"))
        #expect(!memberCreationSource.contains("var humanGender = \"非二元\""))
        #expect(sitterSource.contains("PetBasicInfoHealthSummary.latestWeight"))
        #expect(sitterSource.contains("OhanaFrameScheduler.runAfterNextFrame"))
    }

    @MainActor
    @Test func petProfileHealthSummaryUsesPetScopedRowsAndLedgerWeight() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        context.insert(pet)
        context.insert(otherPet)

        let vaccine = PetHealthLog(
            date: now.addingTimeInterval(-86400),
            type: .vaccine,
            note: "Rabies",
            pet: pet
        )
        vaccine.expirationDate = now.addingTimeInterval(86400 * 30)
        context.insert(vaccine)
        context.insert(PetHealthLog(
            date: now.addingTimeInterval(60),
            type: .vaccine,
            note: "Other pet vaccine",
            pet: otherPet
        ))
        context.insert(PetMedication(
            name: "Antibiotic",
            dosage: "5ml",
            startDate: now.addingTimeInterval(-3600),
            pet: pet
        ))
        context.insert(SymptomLog(
            date: now,
            category: .respiratory,
            symptomName: "Cough",
            severity: .moderate,
            pet: pet
        ))
        context.insert(PetInsurance(
            companyName: "CareCo",
            productName: "Guard Plan",
            renewalDate: now.addingTimeInterval(86400 * 14),
            pet: pet
        ))
        context.insert(PetWeightLog(date: now.addingTimeInterval(120), weight: 99, pet: pet))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.6
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now.addingTimeInterval(60),
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 9.9
        ))
        try context.save()

        let summary = PetBasicInfoHealthSummary.load(petID: pet.id, context: context, now: now)
        let en = L10n("en")
        let de = L10n("de")

        #expect(summary.vaccine?.name == "Rabies")
        #expect(summary.activeMedications.first?.name == "Antibiotic")
        #expect(summary.recentSymptoms.first?.name == "Cough")
        #expect(summary.insurance?.name == "Guard Plan")
        #expect(summary.localizedVaccineSummary(l: en).contains("valid until"))
        #expect(summary.localizedMedicationSummary(l: en).contains("Antibiotic"))
        #expect(summary.localizedSymptomSummary(l: de).contains("Mittel"))
        #expect(summary.localizedInsuranceSummary(l: en).contains("Guard Plan"))
        #expect(summary.latestWeight?.kg == 4.6)
        #expect(!summary.localizedWeightSummary(l: en).contains("99"))
        #expect(!summary.localizedWeightSummary(l: en).contains("9.9"))
    }

    @Test func familyWeeklyReportsUseDeferredLedgerReadModelInsteadOfPetRelationshipLogs() throws {
        let rootURL = repositoryRootURL()
        let cardSource = try source("Ohana/Features/FamilyReports/Views/WeeklyReportCard.swift", rootURL: rootURL)
        let dashboardSource = try source("Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift", rootURL: rootURL)
        let dataContainerSource = try source("Ohana/Features/FamilyReports/FamilyWeeklyReportDataContainer.swift", rootURL: rootURL)
        let snapshotSource = try source("Ohana/Features/FamilyReports/FamilyWeeklyReportRouteSnapshot.swift", rootURL: rootURL)

        for source in [cardSource, dashboardSource] {
            #expect(!source.contains("pet.careLogs"))
            #expect(!source.contains("pet.pottyLogs"))
            #expect(!source.contains("pet.walkLogs"))
            #expect(!source.contains("pet.expenseLogs"))
            #expect(!source.contains("pet.hygieneLogs"))
            #expect(!source.contains("pet.weightLogs"))
            #expect(!source.contains("pet.photoLogs"))
        }
        #expect(!dashboardSource.contains("Fallback keeps older local data visible"))
        #expect(dashboardSource.contains("let snapshot: FamilyWeeklyReportRouteSnapshot"))
        #expect(!dashboardSource.contains("let pets: [Pet]"))
        #expect(!dashboardSource.contains("let humans: [Human]"))
        #expect(!dashboardSource.contains("let ledgerEvents: [CareLedgerEvent]"))
        #expect(!dashboardSource.contains("let healthAlertSources: [PetHealthAlertSource]"))
        #expect(dashboardSource.contains("private var weekPhotoMemories: [FamilyWeeklyPhotoMemory]"))
        #expect(snapshotSource.contains("let modelID: PersistentIdentifier"))
        #expect(snapshotSource.contains("let imageSignature: String"))
        #expect(snapshotSource.contains("let canAttemptImageAttachmentLoad: Bool"))
        #expect(dashboardSource.contains("@State private var mediaBlobLoader: SwiftDataMediaBlobLoader?"))
        #expect(dashboardSource.contains("private func routeMediaBlobLoader() -> SwiftDataMediaBlobLoader"))
        #expect(dashboardSource.contains("let loader = routeMediaBlobLoader()"))
        #expect(dashboardSource.contains("await loader.petPhotoLogImageData(modelID: memory.modelID)"))
        #expect(dashboardSource.contains("asyncDataProvider:"))
        #expect(dashboardSource.contains("sourceSignature: memory.imageSignature"))
        #expect(!dashboardSource.contains("let imageData: Data"))
        #expect(!dashboardSource.contains("AsyncDecodedImageView(data: memory.imageData"))
        #expect(!dashboardSource.contains("return log.imageData"))
        #expect(dashboardSource.contains("snapshot.healthAlerts"))
        #expect(!dashboardSource.contains("scanAlerts(pets: activePets)"))
        #expect(!dashboardSource.contains("appServices.careLedgerStats.reportEntries"))
        #expect(dataContainerSource.contains("FamilyWeeklyReportRouteDataActor(modelContainer: container)"))
        #expect(dataContainerSource.contains("OhanaFrameScheduler.waitAfterNextFrame"))
        #expect(!dataContainerSource.contains("FamilyWeeklyReportRouteData.load(from: modelContext)"))
        #expect(snapshotSource.contains("@ModelActor"))
        #expect(snapshotSource.contains("nonisolated struct FamilyWeeklyReportRouteSnapshot: Sendable"))
        #expect(snapshotSource.contains("var entries: [CareLedgerReportEntry]"))
        #expect(snapshotSource.contains("PetHealthAlertSourceRouteData.load(pets: pets, from: context)"))
        #expect(snapshotSource.contains("FetchDescriptor<PetPhotoLog>"))
        #expect(snapshotSource.contains("FamilyWeeklyPhotoMemory("))
        #expect(snapshotSource.contains("modelID: log.persistentModelID"))
        #expect(snapshotSource.contains("imageSignature: log.imageThumbnailSignature"))
        #expect(snapshotSource.contains("canAttemptImageAttachmentLoad: log.canAttemptImageAttachmentLoad"))
        #expect(!snapshotSource.contains("imageData: log.imageData"))
        #expect(snapshotSource.contains("descriptor.fetchLimit = 1200"))
        #expect(!dataContainerSource.contains("@Query(sort: \\CareLedgerEvent.occurredAt"))
    }

    @Test func familyWeeklyReportActiveContributionExcludesDeceasedMembers() throws {
        let rootURL = repositoryRootURL()
        let dashboardSource = try source(
            "Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift",
            rootURL: rootURL
        )
        let dataContainerSource = try source(
            "Ohana/Features/FamilyReports/FamilyWeeklyReportDataContainer.swift",
            rootURL: rootURL
        )

        #expect(dashboardSource.contains("snapshot.visibleHumanCount"))
        #expect(dataContainerSource.contains("FamilyWeeklyReportRouteDataActor(modelContainer: container)"))
        let snapshotSource = try source("Ohana/Features/FamilyReports/FamilyWeeklyReportRouteSnapshot.swift", rootURL: rootURL)
        #expect(snapshotSource.contains("humans.filter { !$0.hasPassedAway }"))
        #expect(snapshotSource.contains("let visibleHumansById = Dictionary(uniqueKeysWithValues: visibleHumans.map"))
        #expect(snapshotSource.contains("guard id == \"unknown\" || visibleHumansById[id] != nil else { continue }"))
        #expect(dashboardSource.contains("humanCount: visibleHumanCount"))
        #expect(snapshotSource.contains("pets.filter { !$0.hasPassedAway }"))
    }

    @Test func coconutHistoryKeepsFrozenMemberLedgerReadableWhileActiveTotalsExcludeThem() throws {
        let rootURL = repositoryRootURL()
        let logSource = try source("Ohana/Features/Economy/Views/CoconutLogView.swift", rootURL: rootURL)
        let afterVisibleLogs = try #require(
            logSource.components(separatedBy: "private var visibleLogs: [CoconutLogEntry] {").dropFirst().first
        )
        let visibleLogsSection = try #require(
            afterVisibleLogs.components(separatedBy: "private var visibleCoconutTotal: Int {").first
        )
        let afterVisibleTotal = try #require(
            logSource.components(separatedBy: "private var visibleCoconutTotal: Int {").dropFirst().first
        )
        let visibleTotalSection = try #require(
            afterVisibleTotal.components(separatedBy: "private func balance(for actorId: String) -> Int {").first
        )

        #expect(logSource.contains("let frozenActorIds = Set("))
        #expect(logSource.contains("pets.filter { !EconomyWalletWritePolicy.canWrite($0) }"))
        #expect(logSource.contains("humans.filter { !EconomyWalletWritePolicy.canWrite($0) }"))
        #expect(visibleTotalSection.contains("!memberSnapshot.frozenActorIds.contains(account.ownerId)"))
        #expect(visibleLogsSection.contains("walletLedgerEntries"))
        #expect(visibleLogsSection.contains(".filter { $0.delta != 0 }"))
        #expect(visibleLogsSection.contains(".filter { !memberSnapshot.hiddenHumanIds.contains($0.actorId ?? \"\") }"))
        #expect(!visibleLogsSection.contains("frozenActorIds"))
        #expect(!visibleLogsSection.contains("EconomyWalletWritePolicy.canWrite"))
    }

    @Test func streakManagerUsesLedgerNarrowCheckInInsteadOfPetRelationshipLogs() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/Features/Economy/StreakManager.swift", rootURL: rootURL)

        #expect(!source.contains("pet.pottyLogs"))
        #expect(!source.contains("pet.walkLogs"))
        #expect(!source.contains("pet.foodRecords"))
        #expect(source.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(source.contains("descriptor.fetchLimit = 1"))
        #expect(source.contains("event.subjectId == subjectId"))
        #expect(source.contains("event.actionType == feedingAction"))
    }

    @Test func streakManagerCheckInReadsLedgerInsteadOfPetRelationshipLogs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let legacyPotty = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet)
        context.insert(pet)
        context.insert(legacyPotty)
        try context.save()

        StreakManager.refreshStreak(for: pet, context: context)

        #expect(pet.currentStreak == 0)
        #expect(pet.lastCheckInDate == nil)

        context.insert(CareLedgerEvent(
            occurredAt: Date(),
            actorKind: .human,
            actorId: UUID().uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue
        ))
        try context.save()

        StreakManager.refreshStreak(for: pet, context: context)

        #expect(pet.currentStreak == 1)
        #expect(pet.lastCheckInDate != nil)
    }

    @Test func islandNegativeFeedbackUsesLedgerEntriesInsteadOfPetRelationshipLogs() throws {
        let rootURL = repositoryRootURL()
        let feedbackSource = try source("Ohana/Shared/Components/IslandNegativeFeedback.swift", rootURL: rootURL)
        let homeAuxiliarySource = try source("Ohana/Features/Home/Views/FocusHomeAuxiliaryViews.swift", rootURL: rootURL)

        #expect(!feedbackSource.contains("pet.careLogs"))
        #expect(!feedbackSource.contains("pet.walkLogs"))
        #expect(!feedbackSource.contains("pet.pottyLogs"))
        #expect(!feedbackSource.contains("pet.hygieneLogs"))
        #expect(!feedbackSource.contains("[PetCareLog]"))
        #expect(feedbackSource.contains("struct IslandNegativeCareLedgerEntry"))
        #expect(feedbackSource.contains("careLedgerEntries: [IslandNegativeCareLedgerEntry]"))
        #expect(feedbackSource.contains("amountValue"))
        #expect(homeAuxiliarySource.contains("negativeCareLedgerEntries(from: careLedgerEntries)"))
    }

    @Test func islandQuestEngineUsesLedgerEntriesInsteadOfPetRelationshipCareFallbacks() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/Features/TodayFocus/IslandQuestEngine.swift", rootURL: rootURL)

        #expect(!source.contains("pet.careLogs"))
        #expect(!source.contains("pet.walkLogs"))
        #expect(!source.contains("pet.pottyLogs"))
        #expect(!source.contains("pet.weightLogs"))
        #expect(!source.contains("hasPlannedCareLog"))
        #expect(source.contains("hasCareLedgerEntry("))
        #expect(source.contains("lastLedgerRoutineActor"))
    }

    @Test func waterCareCycleStatusUsesExplicitSnapshotInsteadOfPetCareLogRelationship() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/Domain/Services/WaterCareCycleStatus.swift", rootURL: rootURL)

        #expect(!source.contains("pet.careLogs"))
        #expect(!source.contains("latestCareLogDate"))
        #expect(source.contains("(logSnapshot ?? .empty).latestWaterChangeDate"))
        #expect(source.contains("(logSnapshot ?? .empty).latestFilterCleanDate"))
    }

    @Test func focusHomeCardModelUsesExplicitWalkDistanceInsteadOfPetWalkRelationship() throws {
        let rootURL = repositoryRootURL()
        let modelSource = try source("Ohana/Features/Home/FocusHomeModels.swift", rootURL: rootURL)
        let dataSource = try source("Ohana/Features/Home/FocusHomeCardDataSource.swift", rootURL: rootURL)

        #expect(!modelSource.contains("pet.walkLogs"))
        #expect(!modelSource.contains("weeklyWalkDistanceMeters"))
        #expect(!modelSource.contains("includeWalkDistance"))
        #expect(modelSource.contains("homeWalkDistanceMeters: Double = 0"))
        #expect(!dataSource.contains("includeWalkDistance"))
    }

    @Test func islandProsperityUsesLedgerCountsInsteadOfPetRelationshipLogs() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/Features/Economy/IslandProsperityManager.swift", rootURL: rootURL)

        #expect(!source.contains("level(pets:"))
        #expect(!source.contains("progress(pets:"))
        #expect(!source.contains("totalLogCount(pets:"))
        #expect(!source.contains("pet.walkLogs"))
        #expect(!source.contains("pet.pottyLogs"))
        #expect(!source.contains("pet.hygieneLogs"))
        #expect(!source.contains("pet.healthLogs"))
        #expect(!source.contains("pet.weightLogs"))
        #expect(!source.contains("pet.foodRecords"))
        #expect(!source.contains("pet.milestones"))
        #expect(source.contains("totalLogCount(events: [CareLedgerEvent]"))
    }

    @Test func islandProsperityCountsOnlyPetLedgerActivity() {
        let petID = UUID().uuidString
        let otherPetID = UUID().uuidString
        let events = [
            CareLedgerEvent(
                subjectKind: .pet,
                subjectId: petID,
                eventKind: .care,
                actionType: CareType.feeding.rawValue
            ),
            CareLedgerEvent(
                subjectKind: .pet,
                subjectId: petID,
                eventKind: .walk,
                actionType: "walk"
            ),
            CareLedgerEvent(
                subjectKind: .pet,
                subjectId: otherPetID,
                eventKind: .potty,
                actionType: PottyType.pee.rawValue
            ),
            CareLedgerEvent(
                subjectKind: .human,
                subjectId: UUID().uuidString,
                eventKind: .workout,
                actionType: "walk"
            ),
            CareLedgerEvent(
                subjectKind: .pet,
                subjectId: petID,
                eventKind: .coconut,
                actionType: "reward"
            )
        ]

        #expect(IslandProsperityManager.totalLogCount(events: events, petIDs: [petID]) == 2)
        #expect(IslandProsperityManager.totalLogCount(events: events) == 3)
        #expect(IslandProsperityManager.level(totalLogCount: 49) == .seedling)
        #expect(IslandProsperityManager.level(totalLogCount: 50) == .blooming)
        #expect(IslandProsperityManager.level(totalLogCount: 200) == .paradise)
        #expect(IslandProsperityManager.progress(totalLogCount: 25) == 0.5)
        #expect(IslandProsperityManager.progress(totalLogCount: 125) == 0.5)
    }

    @Test func achievementWallRoutesLedgerEventsIntoAchievementContext() throws {
        let rootURL = repositoryRootURL()
        let dataContainerSource = try source("Ohana/Features/Achievements/AchievementWallDataContainer.swift", rootURL: rootURL)
        let wallSource = try source("Ohana/Features/Achievements/Views/AchievementWallView.swift", rootURL: rootURL)
        let progressSource = try source("Ohana/Features/Achievements/Views/AchievementWallContentView+Progress.swift", rootURL: rootURL)
        let completionSource = try source("Ohana/Features/Achievements/Views/AchievementWallContentView+CompletionDates.swift", rootURL: rootURL)
        let managerSource = try source("Ohana/Features/Economy/AchievementManager.swift", rootURL: rootURL)
        let routeDataSource = try source("Ohana/Features/Achievements/AchievementPetActivityRouteData.swift", rootURL: rootURL)

        #expect(dataContainerSource.contains("var careLedgerEvents: [CareLedgerEvent] = []"))
        #expect(dataContainerSource.contains("var petActivitySummaries: [UUID: AchievementPetActivitySummary] = [:]"))
        #expect(dataContainerSource.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(dataContainerSource.contains("event.subjectKind == petSubjectKind"))
        #expect(dataContainerSource.contains("careLedgerEvents: routeData.careLedgerEvents"))
        #expect(dataContainerSource.contains("petActivitySummaries: routeData.petActivitySummaries"))
        #expect(routeDataSource.contains("enum AchievementPetActivityRouteData"))
        #expect(routeDataSource.contains("FetchDescriptor<PetFoodRecord>"))
        #expect(routeDataSource.contains("FetchDescriptor<PetPhotoLog>"))
        #expect(routeDataSource.contains("FetchDescriptor<PetMedication>"))
        #expect(wallSource.contains("careLedgerEvents: careLedgerEvents"))
        #expect(wallSource.contains("petActivitySummaries: petActivitySummaries"))
        #expect(progressSource.contains("activeCareLedgerSummary"))
        #expect(progressSource.contains("activePetActivitySummary"))
        #expect(completionSource.contains("activeCareLedgerSummary"))
        #expect(completionSource.contains("activePetActivitySummary"))
        #expect(managerSource.contains("struct AchievementCareLedgerSummary"))
        #expect(managerSource.contains("struct AchievementPetActivitySummary"))
        #expect(managerSource.contains("careLedgerEvents: [CareLedgerEvent] = []"))
        #expect(managerSource.contains("petActivitySummaries: [UUID: AchievementPetActivitySummary] = [:]"))

        for source in [managerSource, progressSource, completionSource] {
            #expect(!source.contains("pet.careLogs"))
            #expect(!source.contains("pet.walkLogs"))
            #expect(!source.contains("pet.pottyLogs"))
            #expect(!source.contains("pet.hygieneLogs"))
            #expect(!source.contains("pet.weightLogs"))
            #expect(!source.contains("pet.healthLogs"))
            #expect(!source.contains("pet.expenseLogs"))
            #expect(!source.contains("pet.photoLogs"))
            #expect(!source.contains("pet.milestones"))
            #expect(!source.contains("pet.documents"))
            #expect(!source.contains("pet.insurances"))
            #expect(!source.contains("pet.medications"))
            #expect(!source.contains("pet.symptomLogs"))
        }
    }

    @Test func achievementManagerPrefersAuthoritativeLedgerCareSummaryWhenProvided() {
        let pet = Pet(name: "Momo", species: "cat")
        let now = Date()
        let legacyWalk = PetWalkLog(pet: pet)
        legacyWalk.distanceMeters = 200_000
        pet.walkLogs.append(legacyWalk)
        for _ in 0 ..< 20 {
            pet.careLogs.append(PetCareLog(type: .watering, pet: pet))
        }
        for offset in 0 ..< 50 {
            pet.photoLogs.append(PetPhotoLog(imageData: Data([1]), date: now.addingTimeInterval(Double(offset)), pet: pet))
        }
        pet.documents.append(PetDocument(title: "Passport", category: .other, pet: pet))
        pet.symptomLogs.append(SymptomLog(category: .digestive, symptomName: "Nausea", severity: .mild, pet: pet))

        let emptyLedgerAchievements = AchievementManager.compute(
            for: pet,
            context: AchievementComputationContext(careLedgerEvents: [])
        )

        #expect(!isAchievementUnlocked("iron_paw", in: emptyLedgerAchievements))
        #expect(!isAchievementUnlocked("hydration_buddy", in: emptyLedgerAchievements))
        #expect(!isAchievementUnlocked("photo_enthusiast", in: emptyLedgerAchievements))
        #expect(!isAchievementUnlocked("memory_collector", in: emptyLedgerAchievements))
        #expect(!isAchievementUnlocked("protection_ready", in: emptyLedgerAchievements))
        #expect(!isAchievementUnlocked("symptom_watcher", in: emptyLedgerAchievements))

        let ledgerAchievements = AchievementManager.compute(
            for: pet,
            context: AchievementComputationContext(
                careLedgerEvents: [
                    CareLedgerEvent(
                        subjectKind: .pet,
                        subjectId: pet.id.uuidString,
                        eventKind: .walk,
                        actionType: "walk",
                        amountValue: 100_000
                    )
                ] + (0 ..< 14).map { offset in
                    CareLedgerEvent(
                        occurredAt: now.addingTimeInterval(Double(offset) * 60),
                        subjectKind: .pet,
                        subjectId: pet.id.uuidString,
                        eventKind: .care,
                        actionType: CareType.watering.rawValue
                    )
                },
                petActivitySummaries: [
                    pet.id: AchievementPetActivitySummary(
                        foodRecordDates: [now, now.addingTimeInterval(60)],
                        photoDates: (0 ..< 50).map { now.addingTimeInterval(Double($0)) },
                        documentIssueDates: [now],
                        activeMedicationEndDates: [now.addingTimeInterval(-60)],
                        symptomDates: (0 ..< 3).map { now.addingTimeInterval(Double($0)) },
                        documentCount: 1
                    )
                ]
            )
        )

        #expect(isAchievementUnlocked("iron_paw", in: ledgerAchievements))
        #expect(isAchievementUnlocked("hydration_buddy", in: ledgerAchievements))
        #expect(isAchievementUnlocked("photo_enthusiast", in: ledgerAchievements))
        #expect(isAchievementUnlocked("memory_collector", in: ledgerAchievements))
        #expect(isAchievementUnlocked("protection_ready", in: ledgerAchievements))
        #expect(isAchievementUnlocked("symptom_watcher", in: ledgerAchievements))
        #expect(isAchievementUnlocked("stock_keeper", in: ledgerAchievements))
        #expect(isAchievementUnlocked("medication_complete", in: ledgerAchievements))
    }

    @MainActor
    @Test func achievementPetActivityRouteDataScopesActivitySummaries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        context.insert(pet)
        context.insert(otherPet)
        context.insert(PetFoodRecord(brand: "Core", totalGrams: 1000, startDate: now, pet: pet))
        context.insert(PetPhotoLog(imageData: Data([1]), date: now, pet: pet))
        context.insert(PetMilestone(date: now, title: "First climb", pet: pet))
        let document = PetDocument(title: "Passport", category: .other, pet: pet)
        document.issueDate = now
        context.insert(document)
        context.insert(PetInsurance(companyName: "Care", renewalDate: now, pet: pet))
        context.insert(PetMedication(name: "Drops", endDate: now.addingTimeInterval(-60), pet: pet))
        context.insert(SymptomLog(date: now, category: .digestive, symptomName: "Nausea", severity: .mild, pet: pet))
        context.insert(PetPhotoLog(imageData: Data([9]), date: now, pet: otherPet))
        try context.save()

        let summaries = AchievementPetActivityRouteData.loadPetActivitySummaries(from: context, petIDs: [pet.id])
        let summary = try #require(summaries[pet.id])

        #expect(summary.foodRecordCount == 1)
        #expect(summary.photoCount == 1)
        #expect(summary.milestoneCount == 1)
        #expect(summary.documentCount == 1)
        #expect(summary.insuranceCount == 1)
        #expect(summary.symptomCount == 1)
        #expect(summary.completedMedicationEndDates(now: now).count == 1)
        #expect(summaries[otherPet.id] == nil)
    }

    @Test func nonWallAchievementCallersUseLedgerContext() throws {
        let rootURL = repositoryRootURL()
        let oasisSnapshots = try source("Ohana/Features/Oasis/OasisRewardSnapshots.swift", rootURL: rootURL)
        let oasisExecutor = try source("Ohana/Features/Oasis/OasisRewardCommandExecutor.swift", rootURL: rootURL)
        let oasisRuntime = try source("Ohana/Features/Oasis/Views/OasisRewardView+Runtime.swift", rootURL: rootURL)
        let petRetentionModel = try source("Ohana/Features/DashboardRecords/PetRetentionHubScreenModel.swift", rootURL: rootURL)
        let petRetentionView = try source("Ohana/Features/DashboardRecords/Views/PetRetentionHubView.swift", rootURL: rootURL)
        let islandRetentionModel = try source("Ohana/Features/DashboardRecords/IslandRetentionDashboardScreenModel.swift", rootURL: rootURL)
        let islandRetentionView = try source("Ohana/Features/DashboardRecords/Views/IslandRetentionDashboard.swift", rootURL: rootURL)

        #expect(oasisSnapshots.contains("var careLedgerEvents: [CareLedgerEvent] = []"))
        #expect(oasisSnapshots.contains("var petActivitySummaries: [UUID: AchievementPetActivitySummary] = [:]"))
        #expect(oasisSnapshots.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(oasisExecutor.contains("careLedgerEvents: [CareLedgerEvent]"))
        #expect(oasisExecutor.contains("petActivitySummaries: [UUID: AchievementPetActivitySummary]"))
        #expect(oasisExecutor.contains("petActivitySummaries: petActivitySummaries"))
        #expect(!oasisExecutor.contains("pets.flatMap { AchievementManager.compute(for: $0) }"))
        #expect(oasisRuntime.contains("careLedgerEvents: liveData.careLedgerEvents"))
        #expect(oasisRuntime.contains("petActivitySummaries: liveData.petActivitySummaries"))

        #expect(petRetentionModel.contains("var careLedgerEvents: [CareLedgerEvent] = []"))
        #expect(petRetentionModel.contains("struct PetRetentionArchiveMetrics"))
        #expect(petRetentionModel.contains("let achievementActivitySummary: AchievementPetActivitySummary"))
        #expect(petRetentionModel.contains("petActivitySummaries: [pet.id: archiveMetrics.achievementActivitySummary]"))
        #expect(!petRetentionModel.contains("AchievementManager.compute(for: pet)"))
        #expect(petRetentionView.contains("fetchCareLedgerEvents(petID:"))
        #expect(petRetentionView.contains("PetRetentionArchiveMetrics.load(petID: petID, context: context)"))
        #expect(petRetentionView.contains("ArchiveMemorySnapshot(pet: pet, activitySummary: archiveMetrics.activitySummary)"))
        #expect(petRetentionView.contains("OhanaFrameScheduler.runAfterNextFrame"))

        #expect(islandRetentionModel.contains("var careLedgerEvents: [CareLedgerEvent] = []"))
        #expect(islandRetentionModel.contains("archiveMetricsByPetId: [UUID: PetRetentionArchiveMetrics]"))
        #expect(islandRetentionModel.contains("petActivitySummaries: [pet.id: metrics.achievementActivitySummary]"))
        #expect(!islandRetentionModel.contains("AchievementManager.compute(for: pet)"))
        #expect(islandRetentionView.contains("fetchCareLedgerEvents(petIDs:"))
        #expect(islandRetentionView.contains("fetchArchiveMetrics(petIDs: petIDs, context: context)"))
        #expect(islandRetentionView.contains("archiveMetrics: screenModel.archiveMetrics(for: pet.id)"))
        #expect(islandRetentionView.contains("OhanaFrameScheduler.runAfterNextFrame"))

        for source in [petRetentionModel, petRetentionView, islandRetentionModel, islandRetentionView] {
            #expect(!source.contains("pet.careLogs"))
            #expect(!source.contains("pet.walkLogs"))
            #expect(!source.contains("pet.pottyLogs"))
            #expect(!source.contains("pet.hygieneLogs"))
            #expect(!source.contains("pet.weightLogs"))
            #expect(!source.contains("pet.healthLogs"))
            #expect(!source.contains("pet.expenseLogs"))
            #expect(!source.contains("pet.photoLogs"))
            #expect(!source.contains("pet.milestones"))
            #expect(!source.contains("pet.documents"))
            #expect(!source.contains("pet.insurances"))
            #expect(!source.contains("pet.medications"))
        }
    }

    @MainActor
    @Test func petRetentionArchiveMetricsUsesRouteScopedCountsAndLatestMemory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 12)))
        let soon = try #require(calendar.date(byAdding: .day, value: 7, to: now))
        let oldMemoryDate = try #require(calendar.date(byAdding: .day, value: -2, to: now))
        let latestMemoryDate = try #require(calendar.date(byAdding: .hour, value: -3, to: now))
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        context.insert(pet)
        context.insert(otherPet)
        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), date: oldMemoryDate, pet: pet))
        context.insert(PetMilestone(date: latestMemoryDate, title: "First hike", pet: pet))
        context.insert(PetPhotoLog(imageData: Data([9]), date: now, pet: otherPet))
        let document = PetDocument(title: "Passport", category: .other, pet: pet)
        document.expiryDate = soon
        context.insert(document)
        context.insert(PetInsurance(companyName: "Ohana Care", renewalDate: soon, pet: pet))
        context.insert(CareLedgerEvent(
            occurredAt: oldMemoryDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: "health"
        ))
        context.insert(CareLedgerEvent(
            occurredAt: latestMemoryDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "weight",
            amountValue: 4.2
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .weight,
            actionType: "weight",
            amountValue: 9.9
        ))
        try context.save()

        let metrics = PetRetentionArchiveMetrics.load(petID: pet.id, context: context, now: now)

        #expect(metrics.isLoaded)
        #expect(metrics.activitySummary.photoCount == 1)
        #expect(metrics.activitySummary.milestoneCount == 1)
        #expect(metrics.activitySummary.healthCount == 1)
        #expect(metrics.activitySummary.weightCount == 1)
        #expect(metrics.activitySummary.latestWeightKg == 4.2)
        #expect(metrics.activitySummary.documentCount == 1)
        #expect(metrics.activitySummary.insuranceCount == 1)
        #expect(metrics.latestMemoryDate == latestMemoryDate)
        #expect(metrics.expiringProtectionCount == 2)
        #expect(metrics.memoryCount == 2)
        #expect(metrics.protectionCount == 2)
        #expect(metrics.timelineCount(careLedgerEvents: []) == 4)
    }

    @Test func islandWeightDashboardUsesPetLedgerMetricsInsteadOfPetRelationships() throws {
        let rootURL = repositoryRootURL()
        let viewModelSource = try source("Ohana/Features/DashboardRecords/IslandUnifiedStatsViewModel.swift", rootURL: rootURL)
        let viewSource = try source("Ohana/Features/DashboardRecords/Views/IslandWeightDashboard.swift", rootURL: rootURL)

        #expect(viewModelSource.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(viewModelSource.contains("eventKind: .weight"))
        #expect(viewModelSource.contains("eventKind: .walk"))
        #expect(viewSource.contains("weightAbsolutePoints(for: seriesID)"))
        #expect(!viewModelSource.contains("pet.weightLogs"))
        #expect(!viewModelSource.contains("pet.walkLogs"))
        #expect(!viewSource.contains("pet.weightLogs"))
        #expect(!viewSource.contains("pet.walkLogs"))
    }

    @MainActor
    @Test func islandUnifiedStatsUsesPetLedgerMetricsInsteadOfLegacyPetRelationships() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let baselineDate = now.addingTimeInterval(-86400)
        let pet = Pet(name: "Momo", species: "dog")
        context.insert(pet)
        context.insert(PetWeightLog(date: now, weight: 99, pet: pet))
        let legacyWalk = PetWalkLog(startDate: now, pet: pet)
        legacyWalk.distanceMeters = 9000
        context.insert(legacyWalk)
        context.insert(CareLedgerEvent(
            occurredAt: baselineDate,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.0
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.8
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .walk,
            actionType: "walk",
            amountValue: 1200
        ))
        try context.save()

        let viewModel = IslandUnifiedStatsViewModel()
        viewModel.load(modelContext: context, pets: [pet], humans: [])

        #expect(viewModel.weightAbsolutes.map(\.weight) == [4.0, 4.8])
        #expect(!viewModel.weightAbsolutes.contains { $0.weight == 99 })
        #expect(abs(viewModel.totalWeeklyExplorationKm - 1.2) < 0.001)
        #expect(viewModel.weeklyExplorationCount == 1)
        #expect(viewModel.gainChampion?.entityName == "Momo")
    }

    @Test func quickWeightSheetsUseRouteScopedLedgerMetricsInsteadOfPetWeightRelationships() throws {
        let rootURL = repositoryRootURL()
        let genericSource = try source(
            "Ohana/Features/DashboardRecords/Views/GenericWeightEntrySheet.swift",
            rootURL: rootURL
        )
        let quickSource = try source(
            "Ohana/Features/DashboardRecords/Views/QuickWeightSheet.swift",
            rootURL: rootURL
        )

        #expect(!genericSource.contains("pet.weightLogs"))
        #expect(!quickSource.contains("pet.weightLogs"))
        #expect(genericSource.contains("enum PetWeightLedgerRouteMetrics"))
        #expect(genericSource.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(genericSource.contains("CareLedgerEventKind.weight.rawValue"))
        #expect(genericSource.contains("OhanaFrameScheduler.runAfterNextFrame"))
        #expect(quickSource.contains("PetWeightLedgerRouteMetrics.latestWeightKg"))
        #expect(quickSource.contains("OhanaFrameScheduler.runAfterNextFrame"))
    }

    @MainActor
    @Test func quickWeightSheetsUseLedgerLatestWeightInsteadOfLegacyPetRelationship() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        context.insert(PetWeightLog(date: now, weight: 99, pet: pet))
        context.insert(CareLedgerEvent(
            occurredAt: now.addingTimeInterval(-3600),
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.8
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now.addingTimeInterval(60),
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: -1
        ))
        try context.save()

        #expect(PetWeightLedgerRouteMetrics.latestWeightKg(petID: pet.id, context: context) == 4.8)
    }

    @Test func dormantPetChartDashboardBroadReadSurfaceStaysRemoved() {
        let rootURL = repositoryRootURL()
        let path = rootURL.appending(path: "Ohana/Features/DashboardRecords/Views/PetChartDashboard.swift")

        #expect(!FileManager.default.fileExists(atPath: path.path))
    }

    @Test func dormantDogActivityCardBroadReadSurfaceStaysRemoved() {
        let rootURL = repositoryRootURL()
        let path = rootURL.appending(path: "Ohana/Features/Walks/Views/DogActivityCard.swift")

        #expect(!FileManager.default.fileExists(atPath: path.path))
    }

    @Test func petVetSummaryPDFUsesSnapshotInsteadOfPetRelationshipReads() throws {
        let rootURL = repositoryRootURL()
        let pdfSource = try source(
            "Ohana/Features/Documents/Views/PetVetSummaryPDFView.swift",
            rootURL: rootURL
        )
        let retentionSource = try source(
            "Ohana/Features/DashboardRecords/Views/PetRetentionHubView.swift",
            rootURL: rootURL
        )
        let guidedSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailContentView+GuidedHome.swift",
            rootURL: rootURL
        )
        let recordsSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailContentView+Records.swift",
            rootURL: rootURL
        )

        #expect(!pdfSource.contains("pet.healthLogs"))
        #expect(!pdfSource.contains("pet.medications"))
        #expect(!pdfSource.contains("pet.symptomLogs"))
        #expect(!pdfSource.contains("pet.insurances"))
        #expect(!pdfSource.contains("pet.documents"))
        #expect(!pdfSource.contains("pet.weightLogs"))
        #expect(pdfSource.contains("struct PetVetSummaryPDFSnapshot"))
        #expect(pdfSource.contains("PetVetSummaryPDFSnapshot.load(pet: pet, context: context)"))
        #expect(pdfSource.contains("FetchDescriptor<PetHealthLog>"))
        #expect(pdfSource.contains("FetchDescriptor<PetMedication>"))
        #expect(pdfSource.contains("FetchDescriptor<SymptomLog>"))
        #expect(pdfSource.contains("FetchDescriptor<PetInsurance>"))
        #expect(pdfSource.contains("FetchDescriptor<PetDocument>"))
        #expect(pdfSource.contains("FetchDescriptor<CareLedgerEvent>"))
        #expect(retentionSource.contains("PetVetSummaryPDFRenderer.render(pet: pet, context: modelContext)"))
        #expect(guidedSource.contains("PetVetSummaryPDFRenderer.render(pet: pet, context: modelContext)"))
        #expect(recordsSource.contains("PetVetSummaryPDFRenderer.render(pet: pet, context: modelContext)"))
    }

    @MainActor
    @Test func petVetSummaryPDFSnapshotUsesPetScopedRowsAndLedgerWeight() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_782_345_600)
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        context.insert(pet)
        context.insert(otherPet)

        let vaccine = PetHealthLog(date: now.addingTimeInterval(-120), type: .vaccine, note: "Rabies", pet: pet)
        vaccine.expirationDate = now.addingTimeInterval(86400 * 30)
        context.insert(vaccine)
        context.insert(PetHealthLog(date: now, type: .checkup, note: "Other pet", pet: otherPet))
        context.insert(PetMedication(
            name: "Antibiotic",
            dosage: "5ml",
            startDate: now.addingTimeInterval(-3600),
            pet: pet
        ))
        context.insert(SymptomLog(
            date: now,
            category: .respiratory,
            symptomName: "Cough",
            severity: .moderate,
            pet: pet
        ))
        context.insert(PetInsurance(
            companyName: "CareCo",
            productName: "Guard Plan",
            renewalDate: now.addingTimeInterval(86400 * 14),
            pet: pet
        ))
        context.insert(PetDocument(title: "Passport", category: .passport, pet: pet))
        context.insert(PetDocument(title: "Other", category: .other, pet: otherPet))
        context.insert(PetWeightLog(date: now, weight: 99, pet: pet))
        context.insert(CareLedgerEvent(
            occurredAt: now.addingTimeInterval(-3600),
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.2
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 4.8
        ))
        context.insert(CareLedgerEvent(
            occurredAt: now,
            subjectKind: .pet,
            subjectId: otherPet.id.uuidString,
            eventKind: .weight,
            actionType: "petWeight",
            amountValue: 8.8
        ))
        try context.save()

        let snapshot = PetVetSummaryPDFSnapshot.load(pet: pet, context: context, now: now)

        #expect(snapshot.recentHealthLogs.map(\.note) == ["Rabies"])
        #expect(snapshot.activeMedications.map(\.name) == ["Antibiotic"])
        #expect(snapshot.recentSymptoms.map(\.symptomName) == ["Cough"])
        #expect(snapshot.activeInsurance?.productName == "Guard Plan")
        #expect(snapshot.keyDocuments.map(\.title) == ["Passport"])
        #expect(snapshot.latestWeightKg == 4.8)
        #expect(snapshot.weightPoints3Mo.map(\.weightKg) == [4.2, 4.8])
    }

    @Test func expenseHistoryDashboardUsesRouteScopedRowsInsteadOfPetExpenseRelationship() throws {
        let rootURL = repositoryRootURL()
        let dataContainerSource = try source(
            "Ohana/Features/Expenses/ExpenseHistoryDataContainer.swift",
            rootURL: rootURL
        )
        let historySource = try source(
            "Ohana/Features/Expenses/Views/ExpenseHistoryView.swift",
            rootURL: rootURL
        )
        let addExpenseSource = try source(
            "Ohana/Features/Expenses/Views/AddExpenseSheet.swift",
            rootURL: rootURL
        )
        let addExpenseRouteSource = try source(
            "Ohana/Features/Expenses/Views/AddExpenseSheetRouteContainer.swift",
            rootURL: rootURL
        )
        let dashboardSource = try source(
            "Ohana/Features/Expenses/Views/PetExpenseDashboardContent.swift",
            rootURL: rootURL
        )
        let insuranceSource = try source(
            "Ohana/Features/Insurance/Views/PetInsuranceView.swift",
            rootURL: rootURL
        )
        let insuranceRouteSource = try source(
            "Ohana/Features/Insurance/Views/PetInsuranceRouteContainer.swift",
            rootURL: rootURL
        )

        #expect(!historySource.contains("pet.expenseLogs"))
        #expect(!addExpenseSource.contains("pet.expenseLogs"))
        #expect(!addExpenseSource.contains("pet.insurances"))
        #expect(!addExpenseSource.contains("@Query"))
        #expect(!dashboardSource.contains("pet.expenseLogs"))
        #expect(!insuranceSource.contains("pet.insurances"))
        #expect(!insuranceSource.contains("@Query"))
        #expect(!dataContainerSource.contains("@Query"))
        #expect(dataContainerSource.contains("ExpenseHistoryRouteData.load(petID:"))
        #expect(dataContainerSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
        #expect(dataContainerSource.contains("FetchDescriptor<PetExpenseLog>"))
        #expect(dataContainerSource.contains("log.pet?.id == petID"))
        #expect(dataContainerSource.contains("homeRevisionUpdates"))
        #expect(addExpenseRouteSource.contains("RouteFirstFrameDeferredLoad("))
        #expect(addExpenseRouteSource.contains("AddExpenseSheetRouteData.load(petID:"))
        #expect(addExpenseRouteSource.contains("FetchDescriptor<PetExpenseLog>"))
        #expect(addExpenseRouteSource.contains("FetchDescriptor<PetInsurance>"))
        #expect(addExpenseRouteSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
        #expect(addExpenseRouteSource.contains("refreshToken: appServices.domainRevisions.homeRevision"))
        #expect(addExpenseSource.contains("AddInsuranceClaimSheet("))
        #expect(addExpenseSource.contains("allExpenses: routeExpenseLogs"))
        #expect(historySource.contains("let expenseLogs: [PetExpenseLog]"))
        #expect(historySource.contains("var onDataChanged: (() -> Void)?"))
        #expect(historySource.contains("PetExpenseDashboardContent("))
        #expect(historySource.contains("expenseLogs: expenseLogs"))
        #expect(dashboardSource.contains("let expenseLogs: [PetExpenseLog]"))
        #expect(dashboardSource.contains("ExpenseSummaryBuilder.sortedRecent(expenseLogs)"))
        #expect(insuranceSource.contains("routeInsurances.sorted"))
        #expect(insuranceRouteSource.contains("RouteFirstFrameDeferredLoad("))
        #expect(insuranceRouteSource.contains("PetInsuranceRouteData.load(petID:"))
        #expect(insuranceRouteSource.contains("FetchDescriptor<PetInsurance>"))
        #expect(insuranceRouteSource.contains("insurance.pet?.id == petID"))
        #expect(insuranceRouteSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
    }

    @Test func coHealthDashboardsUseSnapshotInsteadOfPetWalkAndWeightRelationships() throws {
        let rootURL = repositoryRootURL()
        let compactContainerSource = try source(
            "Ohana/Features/Health/CoHealthDashboardDataContainer.swift",
            rootURL: rootURL
        )
        let fullContainerSource = try source(
            "Ohana/Features/Health/CoHealthDashboardFullDataContainer.swift",
            rootURL: rootURL
        )
        let compactSource = try source(
            "Ohana/Features/Health/Views/CoHealthDashboardView.swift",
            rootURL: rootURL
        )
        let fullSource = try source(
            "Ohana/Features/Health/Views/CoHealthDashboardFullView.swift",
            rootURL: rootURL
        )
        let snapshotSource = try source(
            "Ohana/Features/Health/CoHealthDashboardSnapshot.swift",
            rootURL: rootURL
        )

        for source in [compactContainerSource, fullContainerSource] {
            #expect(!source.contains("@Query"))
            #expect(source.contains("CoHealthDashboardSnapshot.load(human: human, context: modelContext)"))
            #expect(source.contains("homeRevisionUpdates"))
        }
        for source in [compactSource, fullSource] {
            #expect(!source.contains("pet.walkLogs"))
            #expect(!source.contains("pet.weightLogs"))
            #expect(source.contains("CoHealthDashboardSnapshot"))
        }
        #expect(snapshotSource.contains("CareLedgerEventKind.walk.rawValue"))
        #expect(snapshotSource.contains("CareLedgerEventKind.weight.rawValue"))
        #expect(snapshotSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
    }

    @Test func coHealthDashboardSnapshotUsesLedgerRowsForPetWalkAndWeight() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_006_000)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(human)
        context.insert(pet)

        let legacyWalk = PetWalkLog(startDate: now, pet: pet, executorId: human.id.uuidString)
        legacyWalk.distanceMeters = 9000
        let legacyWeight = PetWeightLog(date: now, weight: 99, pet: pet, executorId: human.id.uuidString)
        context.insert(legacyWalk)
        context.insert(legacyWeight)
        context.insert(
            CareLedgerEvent(
                occurredAt: now,
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .walk,
                actionType: "walk",
                amountValue: 1200,
                amountUnit: "m",
                source: .detail
            )
        )
        context.insert(
            CareLedgerEvent(
                occurredAt: now,
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .weight,
                actionType: "weight",
                amountValue: 4.8,
                amountUnit: "kg",
                source: .detail
            )
        )
        try context.save()

        let snapshot = CoHealthDashboardSnapshot.load(human: human, context: context, now: now)
        let associatedDogs = snapshot.associatedPets(for: human.id, dogsOnly: true)

        #expect(associatedDogs.map(\.name) == ["Momo"])
        #expect(associatedDogs.first?.latestWeightKg == 4.8)
        #expect(abs(snapshot.thisMonthWalkKm(for: human.id, pets: associatedDogs, now: now) - 1.2) < 0.001)
    }

    @Test func medicationSurfacesUseRouteScopedRowsInsteadOfPetMedicationRelationship() throws {
        let rootURL = repositoryRootURL()
        let routeDataSource = try source(
            "Ohana/Features/Medication/PetMedicationRouteData.swift",
            rootURL: rootURL
        )
        let medicationContainerSource = try source(
            "Ohana/Features/Medication/PetMedicationDataContainer.swift",
            rootURL: rootURL
        )
        let islandContainerSource = try source(
            "Ohana/Features/Medication/IslandMedicationDashboardDataContainer.swift",
            rootURL: rootURL
        )
        let detailContainerSource = try source(
            "Ohana/Features/Medication/PetMedicationDetailDataContainer.swift",
            rootURL: rootURL
        )
        let healthContainerSource = try source(
            "Ohana/Features/Health/PetHealthDetailDataContainer.swift",
            rootURL: rootURL
        )
        let medicationSource = try source(
            "Ohana/Features/Medication/Views/PetMedicationView.swift",
            rootURL: rootURL
        )
        let islandSource = try source(
            "Ohana/Features/Medication/Views/IslandMedicationDashboard.swift",
            rootURL: rootURL
        )
        let detailSource = try source(
            "Ohana/Features/Medication/Views/PetMedicationDetailSheet.swift",
            rootURL: rootURL
        )
        let healthSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailView.swift",
            rootURL: rootURL
        )
        let healthOverviewSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailContentView+Overview.swift",
            rootURL: rootURL
        )

        for source in [medicationContainerSource, islandContainerSource, detailContainerSource, healthContainerSource] {
            #expect(!source.contains("@Query"))
            #expect(source.contains("homeRevisionUpdates"))
        }
        for source in [medicationSource, islandSource, detailSource, healthSource, healthOverviewSource] {
            #expect(!source.contains("pet.medications"))
        }
        #expect(!medicationSource.contains("let allEvents: [Event]"))
        #expect(!detailSource.contains("let allEvents: [Event]"))
        #expect(!healthSource.contains("let allEvents: [Event]"))
        #expect(routeDataSource.contains("FetchDescriptor<PetMedication>"))
        #expect(routeDataSource.contains("medication.pet?.id == petID"))
        #expect(routeDataSource.contains("FetchDescriptor<Event>"))
        #expect(routeDataSource.contains("EventType.petMedicationDose.rawValue"))
        #expect(routeDataSource.contains("loadDoseEvents(medicationID:"))
        #expect(routeDataSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
        #expect(medicationSource.contains("let medications: [PetMedication]"))
        #expect(medicationSource.contains("let doseEvents: [Event]"))
        #expect(islandSource.contains("let medicationsByPetID: [UUID: [PetMedication]]"))
        #expect(healthSource.contains("let medications: [PetMedication]"))
        #expect(healthSource.contains("let medicationDoseEvents: [Event]"))
    }

    @Test func medicationRouteDataScopesMedicationRowsAndDoseEvents() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_010_000)
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        let medication = PetMedication(name: "Drops", frequency: .daily, pet: pet)
        let otherMedication = PetMedication(name: "Tablets", frequency: .daily, pet: otherPet)
        let doseEvent = Event(
            title: "Momo drops",
            startDate: now.addingTimeInterval(-3600),
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationDose,
            relatedEntityId: medication.id.uuidString
        )
        let otherDoseEvent = Event(
            title: "Nori tablets",
            startDate: now.addingTimeInterval(-1800),
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationDose,
            relatedEntityId: otherMedication.id.uuidString
        )
        let unrelatedEvent = Event(
            title: "General reminder",
            startDate: now,
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(otherPet)
        context.insert(medication)
        context.insert(otherMedication)
        context.insert(doseEvent)
        context.insert(otherDoseEvent)
        context.insert(unrelatedEvent)
        try context.save()

        let routeData = PetMedicationRouteData.load(petID: pet.id, from: context, now: now)
        let detailDoseEvents = PetMedicationRouteData.loadDoseEvents(medicationID: medication.id, from: context, now: now)
        let islandData = IslandMedicationRouteData.load(from: context)

        #expect(routeData.medications.map(\.name) == ["Drops"])
        #expect(routeData.doseEvents.map(\.title) == ["Momo drops"])
        #expect(detailDoseEvents.map(\.title) == ["Momo drops"])
        #expect(islandData.medicationsByPetID[pet.id]?.map(\.name) == ["Drops"])
        #expect(islandData.medicationsByPetID[otherPet.id]?.map(\.name) == ["Tablets"])
    }

    @Test func healthSurfacesUseRouteScopedRowsInsteadOfPetHealthRelationships() throws {
        let rootURL = repositoryRootURL()
        let routeDataSource = try source(
            "Ohana/Features/Health/PetHealthRouteData.swift",
            rootURL: rootURL
        )
        let detailContainerSource = try source(
            "Ohana/Features/Health/PetHealthDetailDataContainer.swift",
            rootURL: rootURL
        )
        let islandContainerSource = try source(
            "Ohana/Features/Health/IslandHealthDashboardDataContainer.swift",
            rootURL: rootURL
        )
        let detailSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailView.swift",
            rootURL: rootURL
        )
        let recordsSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailContentView+Records.swift",
            rootURL: rootURL
        )
        let overviewSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailContentView+Overview.swift",
            rootURL: rootURL
        )
        let routingSource = try source(
            "Ohana/Features/Health/Views/PetHealthDetailContentView+Routing.swift",
            rootURL: rootURL
        )
        let archiveSource = try source(
            "Ohana/Features/Health/Views/PetHealthArchiveView.swift",
            rootURL: rootURL
        )
        let passportSource = try source(
            "Ohana/Features/Health/Views/VaccinePassportView.swift",
            rootURL: rootURL
        )
        let logCardSource = try source(
            "Ohana/Features/Health/Views/PetHealthLogCard.swift",
            rootURL: rootURL
        )
        let immunitySource = try source(
            "Ohana/Features/Health/Views/PetImmunityCard.swift",
            rootURL: rootURL
        )
        let alertEngineSource = try source(
            "Ohana/Features/Health/PetHealthAlertEngine.swift",
            rootURL: rootURL
        )
        let forbiddenRelationshipReads = [
            "pet.activeHealthLogs",
            "pet.activeSymptomLogs",
            "pet.activeHeatCycleLogs",
            "pet.healthLogs",
            "pet.symptomLogs",
            "pet.heatCycleLogs"
        ]

        for source in [detailContainerSource, islandContainerSource] {
            #expect(!source.contains("@Query"))
            #expect(source.contains("homeRevisionUpdates"))
            #expect(source.contains("OhanaFrameScheduler.runAfterNextFrame"))
        }
        for source in [
            detailSource,
            recordsSource,
            overviewSource,
            routingSource,
            archiveSource,
            passportSource,
            logCardSource,
            immunitySource
        ] {
            for forbidden in forbiddenRelationshipReads {
                #expect(!source.contains(forbidden))
            }
        }
        #expect(routeDataSource.contains("struct PetHealthRouteData"))
        #expect(routeDataSource.contains("PetHealthAlertSourceRouteData"))
        #expect(routeDataSource.contains("struct IslandHealthRouteData"))
        #expect(routeDataSource.contains("FetchDescriptor<PetHealthLog>"))
        #expect(routeDataSource.contains("FetchDescriptor<SymptomLog>"))
        #expect(routeDataSource.contains("FetchDescriptor<HeatCycleLog>"))
        #expect(routeDataSource.contains("static func load(pets: [Pet], from context: ModelContext)"))
        #expect(routeDataSource.contains("allowedPetIDs.contains(id)"))
        #expect(routeDataSource.contains("log.pet?.id == petID"))
        #expect(routeDataSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
        #expect(detailSource.contains("let healthLogs: [PetHealthLog]"))
        #expect(detailSource.contains("let symptomLogs: [SymptomLog]"))
        #expect(detailSource.contains("let heatCycleLogs: [HeatCycleLog]"))
        #expect(detailSource.contains("let healthAlertSource: PetHealthAlertSource?"))
        #expect(detailSource.contains("scanAlerts(sources: [healthAlertSource], localization: l)"))
        #expect(alertEngineSource.contains("func scanAlerts(sources: [PetHealthAlertSource], localization l: L10n = L10n())"))
    }

    @Test func petHealthRouteDataScopesHealthRowsAndAlertSource() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let pet = Pet(name: "Momo", species: "猫")
        let otherPet = Pet(name: "Nori", species: "狗")
        let vaccine = PetHealthLog(
            date: now.addingTimeInterval(-86400),
            type: .vaccine,
            note: "Rabies",
            pet: pet
        )
        vaccine.expirationDate = now.addingTimeInterval(-3600)
        let otherVaccine = PetHealthLog(
            date: now,
            type: .vaccine,
            note: "Other vaccine",
            pet: otherPet
        )
        let symptom = SymptomLog(
            date: now,
            category: .respiratory,
            symptomName: "Cough",
            severity: .severe,
            pet: pet
        )
        let otherSymptom = SymptomLog(
            date: now,
            category: .skin,
            symptomName: "Itch",
            severity: .mild,
            pet: otherPet
        )
        let heatCycle = HeatCycleLog(
            startDate: now.addingTimeInterval(-7200),
            status: .estrus,
            pet: pet
        )
        context.insert(pet)
        context.insert(otherPet)
        context.insert(vaccine)
        context.insert(otherVaccine)
        context.insert(symptom)
        context.insert(otherSymptom)
        context.insert(heatCycle)
        context.insert(PetWeightLog(date: now, weight: 4.8, pet: pet))
        context.insert(PetWeightLog(date: now, weight: 28, pet: otherPet))
        try context.save()

        let routeData = PetHealthRouteData.load(petID: pet.id, from: context)
        let islandData = IslandHealthRouteData.load(from: context)
        let bulkSources = PetHealthAlertSourceRouteData.load(pets: [pet, otherPet], from: context)
        let source = try #require(routeData.alertSource)
        let bulkSource = try #require(bulkSources.first { $0.petId == pet.id })
        let otherBulkSource = try #require(bulkSources.first { $0.petId == otherPet.id })
        let alerts = PetHealthAlertEngine().scanAlerts(sources: [source])
        let germanAlerts = PetHealthAlertEngine().scanAlerts(sources: [source], localization: L10n("de"))

        #expect(routeData.healthLogs.map(\.note) == ["Rabies"])
        #expect(routeData.symptomLogs.map(\.symptomName) == ["Cough"])
        #expect(routeData.heatCycleLogs.map(\.status) == [.estrus])
        #expect(source.healthLogs.map(\.note) == ["Rabies"])
        #expect(source.symptomLogs.map(\.symptomName) == ["Cough"])
        #expect(source.weightLogs.map(\.weight) == [4.8])
        #expect(bulkSource.healthLogs.map(\.note) == ["Rabies"])
        #expect(bulkSource.symptomLogs.map(\.symptomName) == ["Cough"])
        #expect(bulkSource.weightLogs.map(\.weight) == [4.8])
        #expect(otherBulkSource.healthLogs.map(\.note) == ["Other vaccine"])
        #expect(otherBulkSource.weightLogs.map(\.weight) == [28])
        #expect(islandData.healthLogsByPetID[pet.id]?.map(\.note) == ["Rabies"])
        #expect(islandData.healthLogsByPetID[otherPet.id]?.map(\.note) == ["Other vaccine"])
        #expect(alerts.contains { $0.type == .vaccineExpired && $0.petId == pet.id })
        #expect(germanAlerts.contains { $0.type == .vaccineExpired && $0.title == "Impfung abgelaufen" })
        #expect(alerts.contains { $0.type == .activeSymptom && $0.petId == pet.id })
        #expect(!alerts.contains { $0.petId == otherPet.id })
    }

    @Test func functionMenuAggregateUsesRouteScopedSummariesInsteadOfPetArchiveRelationships() throws {
        let rootURL = repositoryRootURL()
        let aggregateSource = try source(
            "Ohana/Features/FunctionMenu/Views/FeatureAggregateView.swift",
            rootURL: rootURL
        )
        let routeSource = try source(
            "Ohana/Features/FunctionMenu/FunctionMenuRouteContainer.swift",
            rootURL: rootURL
        )
        let routerSource = try source(
            "Ohana/Features/FunctionMenu/Views/FunctionMenuDestinationRouter.swift",
            rootURL: rootURL
        )
        let groupSource = try source(
            "Ohana/Features/FunctionMenu/Views/FeatureGroupDashboardView.swift",
            rootURL: rootURL
        )

        #expect(!aggregateSource.contains("pet.documents.count"))
        #expect(!aggregateSource.contains("pet.photoLogs.count"))
        #expect(!aggregateSource.contains("pet.milestones.count"))
        #expect(aggregateSource.contains("petAggregateSummaries[pet.id]"))
        #expect(routeSource.contains("struct FunctionMenuPetAggregateSummary"))
        #expect(routeSource.contains("FetchDescriptor<PetDocument>"))
        #expect(routeSource.contains("FetchDescriptor<PetPhotoLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetMilestone>"))
        #expect(routeSource.contains("context.fetchCount(descriptor)"))
        #expect(routerSource.contains("petAggregateSummaries: petAggregateSummaries"))
        #expect(groupSource.contains("petAggregateSummaries: petAggregateSummaries"))
    }

    @Test func functionMenuSurfacesDoNotExposeDeceasedMembersAsActiveTargets() throws {
        let rootURL = repositoryRootURL()
        let rootSource = try source(
            "Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift",
            rootURL: rootURL
        )
        let groupSource = try source(
            "Ohana/Features/FunctionMenu/Views/FeatureGroupDashboardView.swift",
            rootURL: rootURL
        )
        let aggregateSource = try source(
            "Ohana/Features/FunctionMenu/Views/FeatureAggregateView.swift",
            rootURL: rootURL
        )

        for surface in [rootSource, groupSource, aggregateSource] {
            #expect(surface.contains("private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }"))
            #expect(surface.contains("private var visibleHumans: [Human] { humans.filter { !$0.hasPassedAway } }"))
        }
        #expect(aggregateSource.contains("ForEach(chipsForFeature)"))
        #expect(aggregateSource.contains("ForEach(humansForFeature)"))
        #expect(aggregateSource.contains("ForEach(activePets)"))
        #expect(aggregateSource.contains("appServices.privacy.unlockedHumans(for: .weight, from: visibleHumans"))
        #expect(aggregateSource.contains("appServices.privacy.unlockedHumans(for: .expense, from: visibleHumans"))
    }

    @MainActor
    @Test func functionMenuPetAggregateSummaryCountsRouteScopedArchiveItems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let otherPet = Pet(name: "Nori", species: "dog")
        context.insert(pet)
        context.insert(otherPet)
        context.insert(PetDocument(title: "Passport", category: .passport, pet: pet))
        context.insert(PetPhotoLog(imageData: Data([1, 2, 3]), pet: pet))
        context.insert(PetMilestone(title: "First hike", pet: pet))
        context.insert(PetDocument(title: "Other", category: .other, pet: otherPet))
        context.insert(PetPhotoLog(imageData: Data([9]), pet: otherPet))
        try context.save()

        let summaries = FunctionMenuPetAggregateSummary.load(pets: [pet, otherPet], context: context)

        #expect(summaries[pet.id]?.documentCount == 1)
        #expect(summaries[pet.id]?.photoCount == 1)
        #expect(summaries[pet.id]?.milestoneCount == 1)
        #expect(summaries[otherPet.id]?.documentCount == 1)
        #expect(summaries[otherPet.id]?.photoCount == 1)
        #expect(summaries[otherPet.id]?.milestoneCount == 0)
    }

    @Test func archiveFeatureViewsUseRouteScopedRowsInsteadOfPetRelationships() throws {
        let rootURL = repositoryRootURL()
        let documentsListSource = try source(
            "Ohana/Features/Documents/Views/DocumentsListView.swift",
            rootURL: rootURL
        )
        let documentsRouteSource = try source(
            "Ohana/Features/Documents/Views/DocumentsListRouteContainer.swift",
            rootURL: rootURL
        )
        let milestoneListSource = try source(
            "Ohana/Features/Milestones/Views/PetMilestoneListView.swift",
            rootURL: rootURL
        )
        let milestoneRouteSource = try source(
            "Ohana/Features/Milestones/Views/PetMilestoneListRouteContainer.swift",
            rootURL: rootURL
        )
        let milestoneModelSource = try source(
            "Ohana/Models/PetMilestone.swift",
            rootURL: rootURL
        )
        let protectionStateSource = try source(
            "Ohana/Features/Insurance/Views/ProtectionDashboardComponents.swift",
            rootURL: rootURL
        )
        let allFeaturesSource = try source(
            "Ohana/Features/Members/Views/PetAllFeaturesSheet.swift",
            rootURL: rootURL
        )

        #expect(!documentsListSource.contains("pet.documents"))
        #expect(!documentsListSource.contains("pet.insurances"))
        #expect(!documentsListSource.contains("@Query"))
        #expect(documentsRouteSource.contains("RouteFirstFrameDeferredLoad("))
        #expect(documentsRouteSource.contains("DocumentsListRouteData.load(petID:"))
        #expect(documentsRouteSource.contains("FetchDescriptor<PetDocument>"))
        #expect(documentsRouteSource.contains("FetchDescriptor<PetInsurance>"))
        #expect(documentsRouteSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: "Ohana/Features/Documents/Views/PetDocumentsCard.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: "Ohana/Features/Milestones/Views/PetMilestonesCard.swift").path
        ))
        #expect(!milestoneListSource.contains("pet.milestones"))
        #expect(!milestoneListSource.contains("@Query"))
        #expect(milestoneListSource.contains("sourceSignature: milestone.photoThumbnailSignature"))
        #expect(milestoneListSource.contains("milestonePhotoData(for: milestone)"))
        #expect(milestoneListSource.contains("asyncDataProvider:"))
        #expect(milestoneListSource.contains("@State private var mediaBlobLoader: SwiftDataMediaBlobLoader?"))
        #expect(milestoneListSource.contains("private func routeMediaBlobLoader() -> SwiftDataMediaBlobLoader"))
        #expect(milestoneListSource.contains("let loader = routeMediaBlobLoader()"))
        #expect(milestoneListSource.contains("await loader.petMilestonePhotoData(modelID: milestone.persistentModelID)"))
        #expect(!milestoneListSource.contains("modelContext.model(for: milestone.persistentModelID) as? PetMilestone"))
        #expect(!milestoneListSource.contains("return rehydrated.photoData"))
        #expect(!milestoneListSource.contains("if let photoData = milestone.photoData"))
        #expect(!milestoneListSource.contains("if let data = milestone.photoData"))
        #expect(milestoneModelSource.contains("@Attribute(.externalStorage) var photoData: Data?"))
        #expect(milestoneModelSource.contains("var photoImageSignature: String = \"\""))
        #expect(milestoneModelSource.contains("var photoThumbnailSignature: String"))
        #expect(milestoneModelSource.contains("func repairPhotoAttachmentIndexIfNeeded()"))
        #expect(milestoneRouteSource.contains("RouteFirstFrameDeferredLoad("))
        #expect(milestoneRouteSource.contains("PetMilestoneListRouteData.load(petID:"))
        #expect(milestoneRouteSource.contains("FetchDescriptor<PetMilestone>"))
        #expect(milestoneRouteSource.contains("return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch"))
        #expect(!protectionStateSource.contains("pet.documents"))
        #expect(!protectionStateSource.contains("pet.insurances"))
        #expect(protectionStateSource.contains("init(documents: [PetDocument], insurances: [PetInsurance]"))
        #expect(!allFeaturesSource.contains("healthCount: pet.healthLogs.count"))
        #expect(!allFeaturesSource.contains("documentCount: pet.documents.count"))
    }

    @Test func protectionDashboardStateUsesSuppliedArchiveRows() {
        let now = Date(timeIntervalSince1970: 1_782_345_600)
        let expiredDocument = PetDocument(title: "Passport", category: .passport)
        expiredDocument.expiryDate = now.addingTimeInterval(-86400)
        let futureInsurance = PetInsurance(
            companyName: "Ohana Care",
            renewalDate: now.addingTimeInterval(86400 * 90)
        )

        let state = PetProtectionDashboardState(
            documents: [expiredDocument],
            insurances: [futureInsurance],
            now: now
        )

        #expect(state.documentCount == 1)
        #expect(state.insuranceCount == 1)
        #expect(state.documentsRisk == ProtectionRiskLevel.expired)
        #expect(state.insuranceRisk == ProtectionRiskLevel.protected)
        #expect(state.nextInsuranceDate == futureInsurance.renewalDate)
    }

    @Test func petMomentsTimelineUsesRouteScopedRowsInsteadOfPetRelationships() throws {
        let rootURL = repositoryRootURL()
        let builderSource = try source(
            "Ohana/Features/PetCare/PetTimelineModels.swift",
            rootURL: rootURL
        )
        let hubSource = try source(
            "Ohana/Features/Moments/Views/PetMomentsHubView.swift",
            rootURL: rootURL
        )
        let routeSource = try source(
            "Ohana/Features/Moments/Views/PetMomentsHubRouteContainer.swift",
            rootURL: rootURL
        )
        let albumSource = try source(
            "Ohana/Features/PhotoAlbum/Views/PetPhotoAlbumView.swift",
            rootURL: rootURL
        )
        let forbiddenRelationshipReads = [
            "pet.careLogs",
            "pet.pottyLogs",
            "pet.walkLogs",
            "pet.healthLogs",
            "pet.weightLogs",
            "pet.expenseLogs",
            "pet.photoLogs",
            "pet.milestones"
        ]

        for forbidden in forbiddenRelationshipReads {
            #expect(!builderSource.contains(forbidden))
            #expect(!hubSource.contains(forbidden))
            #expect(!albumSource.contains(forbidden))
        }
        #expect(builderSource.contains("struct PetTimelineSourceRows"))
        #expect(builderSource.contains("sourceRows.walkLogs"))
        #expect(builderSource.contains("sourceRows.photoLogs"))
        #expect(builderSource.contains("sourceRows.milestones"))
        #expect(builderSource.contains("struct PetTimelineRenderItem"))
        #expect(builderSource.contains("struct PetTimelinePhotoReference"))
        #expect(builderSource.contains("struct PetMomentsHubRenderData: Sendable"))
        #expect(hubSource.contains("let renderData: PetMomentsHubRenderData"))
        #expect(hubSource.contains("let albumRenderData: PetPhotoAlbumRenderData"))
        #expect(!hubSource.contains(".onAppear(perform: refreshRenderData)"))
        #expect(!hubSource.contains("PetMomentsHubRenderData.build("))
        #expect(hubSource.contains("PetPhotoAlbumView(pet: pet, renderData: albumRenderData"))
        #expect(!hubSource.contains("PetPhotoAlbumView(pet: pet, photoLogs:"))
        #expect(albumSource.contains("let renderData: PetPhotoAlbumRenderData"))
        #expect(!albumSource.contains("let photoLogs: [PetPhotoLog]"))
        #expect(!albumSource.contains("PetPhotoAlbumRenderData.build(photoLogs: photoLogs)"))
        #expect(!routeSource.contains("@Query"))
        #expect(!routeSource.contains("PetMomentsHubRouteData.load"))
        #expect(routeSource.contains("@ModelActor"))
        #expect(routeSource.contains("PetMomentsHubRouteDataActor"))
        #expect(routeSource.contains("PetMomentsHubRouteDataReference: Sendable"))
        #expect(routeSource.contains("renderData = reference.renderData"))
        #expect(routeSource.contains("albumRenderData = reference.albumRenderData"))
        #expect(routeSource.contains("PetMomentsHubRenderData.build("))
        #expect(routeSource.contains("PetPhotoAlbumRenderData.build("))
        #expect(routeSource.contains("[PersistentIdentifier]"))
        #expect(routeSource.contains("context.model(for: $0) as? T"))
        #expect(routeSource.contains("PetTimelineSourceRows("))
        #expect(!routeSource.contains("var timelineRows = PetTimelineSourceRows.empty"))
        #expect(!routeSource.contains("PetTimelineSourceRowReferences"))
        #expect(!routeSource.contains("photoLogs: Self.rehydrate(reference.timelineRows.photoLogs"))
        #expect(routeSource.contains("FetchDescriptor<PetCareLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetPottyLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetWalkLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetHealthLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetExpenseLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetWeightLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetPhotoLog>"))
        #expect(routeSource.contains("FetchDescriptor<PetMilestone>"))
        #expect(!routeSource.contains("// route-first-frame: allow deferred-fetch"))
        #expect(albumSource.contains("struct PetPhotoAlbumPhotoItem"))
        #expect(albumSource.contains("let modelID: PersistentIdentifier"))
        #expect(albumSource.contains("let photos: [PetPhotoAlbumPhotoItem]"))
        #expect(albumSource.contains("@State private var selectedPhoto: PetPhotoAlbumPhotoItem?"))
        #expect(albumSource.contains("let photo: PetPhotoAlbumPhotoItem"))
        #expect(albumSource.contains("modelContext.model(for: photo.modelID) as? PetPhotoLog"))
        #expect(albumSource.contains("@State private var mediaBlobLoader: SwiftDataMediaBlobLoader?"))
        #expect(albumSource.contains("private func routeMediaBlobLoader() -> SwiftDataMediaBlobLoader"))
        #expect(albumSource.contains("let loader = routeMediaBlobLoader()"))
        #expect(albumSource.contains("await loader.petPhotoLogImageData(modelID: photo.modelID)"))
        #expect(albumSource.contains("asyncDataProvider:"))
        #expect(!albumSource.contains("let photos: [PetPhotoLog]"))
        #expect(!albumSource.contains("@State private var selectedPhoto: PetPhotoLog?"))
        #expect(!albumSource.contains("let photo: PetPhotoLog"))
        #expect(!albumSource.contains("photo.canAttemptImageAttachmentLoad ? photo.imageData : nil"))
        #expect(!albumSource.contains("return photoLog.imageData"))
        #expect(hubSource.contains("@State private var mediaBlobLoader: SwiftDataMediaBlobLoader?"))
        #expect(hubSource.contains("private func routeMediaBlobLoader() -> SwiftDataMediaBlobLoader"))
        #expect(hubSource.contains("let loader = routeMediaBlobLoader()"))
        #expect(hubSource.contains("await loader.petPhotoLogImageData(modelID: photo.modelID)"))
        #expect(!hubSource.contains("return log.imageData"))
    }

    @Test func featureHubAvatarsUseLazyMediaProviderInsteadOfRenderBlobReads() throws {
        let rootURL = repositoryRootURL()
        let componentSource = try source(
            "Ohana/Shared/Components/FeatureHubComponents.swift",
            rootURL: rootURL
        )
        let migratedSources = [
            "Ohana/Features/Moments/Views/PetMomentsHubView.swift",
            "Ohana/Features/Moments/Views/QuickMomentSheet.swift",
            "Ohana/Shared/Components/HumanModuleV4Components.swift",
            "Ohana/Features/Economy/Views/PetBondVaultView.swift",
            "Ohana/Features/Plants/Views/PlantAllFeaturesSheet.swift",
            "Ohana/Features/Members/Views/PetAllFeaturesSheet.swift",
            "Ohana/Features/DashboardRecords/Views/PetRetentionHubView.swift",
            "Ohana/Features/Medication/Views/PetMedicationDetailSheet.swift",
            "Ohana/Features/Medication/Views/PetMedicationView.swift",
            "Ohana/Features/Expenses/Views/HumanWeightDashboardContent.swift",
            "Ohana/Features/Expenses/Views/HumanExpenseDashboardContent.swift",
            "Ohana/Features/Expenses/Views/PetWeightDashboardContent.swift",
            "Ohana/Features/Expenses/Views/PetExpenseDashboardContent.swift"
        ]
        let forbiddenDirectAvatarReads = [
            "imageData: pet.hasAvatarImageAttachment ? pet.avatarImageData : nil",
            "imageData: human.hasAvatarImageAttachment ? human.avatarImageData : nil",
            "imageData: plant.hasAvatarImageAttachment ? plant.avatarImageData : nil"
        ]

        #expect(componentSource.contains("imageDataProvider: @escaping @MainActor () -> Data?"))
        #expect(componentSource.contains("asyncImageDataProvider: @escaping @Sendable () async -> Data?"))
        #expect(componentSource.contains("MediaThumbnailProvider.imageWithTransparency"))

        for path in migratedSources {
            let fileSource = try source(path, rootURL: rootURL)
            #expect(fileSource.contains("imageSignature:"))
            #expect(
                fileSource.contains("imageDataProvider:")
                    || fileSource.contains("asyncImageDataProvider:")
                    || fileSource.contains("ModelID:")
            )
            for forbidden in forbiddenDirectAvatarReads {
                #expect(!fileSource.contains(forbidden))
            }
        }
    }

    @Test func avatarPortraitEntrypointsDoNotPassExternalStorageBlobsAsRenderParameters() throws {
        let rootURL = repositoryRootURL()
        let portraitSource = try source(
            "Ohana/Shared/Components/PetAvatarPortraitView.swift",
            rootURL: rootURL
        )
        let forbiddenDirectAvatarReads = [
            "imageData: pet.hasAvatarImageAttachment ? pet.avatarImageData : nil",
            "imageData: human.hasAvatarImageAttachment ? human.avatarImageData : nil",
            "imageData: plant.hasAvatarImageAttachment ? plant.avatarImageData : nil"
        ]

        #expect(portraitSource.contains("imageSignature: pet.avatarThumbnailSignature"))
        #expect(portraitSource.contains("MediaThumbnailProvider.imageWithTransparency"))

        for path in try swiftSourcePaths(under: ["Ohana/Features", "Ohana/Shared"], rootURL: rootURL) {
            let fileSource = try source(path, rootURL: rootURL)
            for forbidden in forbiddenDirectAvatarReads {
                #expect(!fileSource.contains(forbidden))
            }
        }
    }

    @Test func petTimelineBuilderUsesSuppliedRowsInsteadOfPetRelationships() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let relationshipLog = PetCareLog(
            date: Date(timeIntervalSince1970: 1000),
            type: .feeding,
            amountGrams: 42,
            pet: pet
        )
        context.insert(pet)
        context.insert(relationshipLog)
        try context.save()

        let emptyItems = PetTimelineItemsBuilder.items(
            for: pet,
            sourceRows: .empty,
            l: L10n("en")
        )
        let suppliedItems = PetTimelineItemsBuilder.items(
            for: pet,
            sourceRows: PetTimelineSourceRows(careLogs: [relationshipLog]),
            l: L10n("en")
        )

        #expect(emptyItems.isEmpty)
        #expect(suppliedItems.contains { $0.id == relationshipLog.id && $0.type == "care" })
    }

    @Test func familyCareLedgerEntriesProjectWeeklyStatsAndExecutorLists() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 12)))
        let weekStart = FamilyCareLedgerEntry.weekStart(now: now, calendar: calendar)
        let weekEnd = try #require(calendar.date(byAdding: .day, value: 7, to: weekStart))
        let petID = UUID()
        let otherPetID = UUID()
        let humanA = UUID().uuidString
        let humanB = UUID().uuidString
        let humanC = UUID().uuidString

        let care = CareLedgerEvent(
            occurredAt: weekStart.addingTimeInterval(3600),
            actorKind: .human,
            actorId: humanA,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .care,
            actionType: CareType.watering.rawValue
        )
        let walk = CareLedgerEvent(
            occurredAt: weekStart.addingTimeInterval(7200),
            actorKind: .human,
            actorId: humanB,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .walk,
            actionType: "walk",
            metadataJSON: "{\"executorIds\":[\"\(humanB)\",\"\(humanC)\"]}"
        )
        let expense = CareLedgerEvent(
            occurredAt: weekStart.addingTimeInterval(10800),
            actorKind: .human,
            actorId: humanC,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.food.rawValue
        )
        let otherPet = CareLedgerEvent(
            occurredAt: weekStart.addingTimeInterval(12000),
            actorKind: .human,
            actorId: humanA,
            subjectKind: .pet,
            subjectId: otherPetID.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue
        )
        let outsideWeek = CareLedgerEvent(
            occurredAt: weekStart.addingTimeInterval(-60),
            actorKind: .human,
            actorId: humanA,
            subjectKind: .pet,
            subjectId: petID.uuidString,
            eventKind: .potty,
            actionType: PottyType.pee.rawValue
        )

        let entries = FamilyCareLedgerEntry.entries(
            from: [care, walk, expense, otherPet, outsideWeek],
            petIDs: [petID],
            start: weekStart,
            end: weekEnd
        )

        #expect(entries.map(\.kind) == [.care, .walk, .expense])
        #expect(entries.map(\.executorIDs) == [[humanA], [humanB, humanC], [humanC]])
        #expect(entries.map(\.petID) == [petID, petID, petID])
    }

    @Test func deceasedPetCannotDeleteOrUndoCareFacts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_113)
        let careLog = PetCareLog(
            date: Date(timeIntervalSince1970: 1_800_000_900),
            type: .play,
            pet: pet,
            executorId: nil
        )
        let pottyLog = PetPottyLog(
            date: Date(timeIntervalSince1970: 1_800_001_000),
            type: .perfectPoop,
            pet: pet,
            executorId: nil
        )
        let hygieneLog = PetHygieneLog(
            date: Date(timeIntervalSince1970: 1_800_001_100),
            type: .bath,
            pet: pet,
            executorId: nil
        )
        let catEvent = Event(
            title: "Litter",
            startDate: Date(timeIntervalSince1970: 1_800_001_200),
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let catHygieneLog = PetHygieneLog(
            date: Date(timeIntervalSince1970: 1_800_001_200),
            type: .bath,
            pet: pet,
            executorId: nil
        )
        context.insert(pet)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(catEvent)
        context.insert(catHygieneLog)
        try context.save()

        let careDelete = PetCareTrackingCommandService.deleteCareLog(careLog, pet: pet, context: context)
        let pottyDelete = PetPottyCommandService.deletePottyLog(pottyLog, pet: pet, context: context)
        let hygieneDelete = PetHygieneCommandService.delete(hygieneLog, pet: pet, context: context)
        let undo = CatCareCommandService.undo(
            pet: pet,
            eventID: catEvent.id,
            hygieneLogID: catHygieneLog.id,
            context: context
        )

        #expect(!careDelete.didDelete)
        #expect(!pottyDelete.didDelete)
        #expect(!hygieneDelete.didDelete)
        #expect(!undo.didDelete)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).map(\.id) == [careLog.id])
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).map(\.id) == [pottyLog.id])
        #expect(Set(try context.fetch(FetchDescriptor<PetHygieneLog>()).map(\.id)) == [hygieneLog.id, catHygieneLog.id])
        #expect(try context.fetch(FetchDescriptor<Event>()).map(\.id) == [catEvent.id])
        #expect(try context.fetch(FetchDescriptor<CloudSyncRecordState>()).allSatisfy { !$0.isDeletionTombstone })
    }

    @Test func deceasedPetCanStillWriteMemorialPhotosWithoutCareEffects() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_109)
        context.insert(pet)
        try context.save()

        let result = try PetPhotoAlbumCommandService.createPhotos(
            data: [Data([1, 2, 3])],
            pet: pet,
            context: context,
            date: Date(timeIntervalSince1970: 1_800_000_500)
        )

        #expect(result.petID == pet.id)
        #expect(result.photoIDs.count == 1)
        #expect(try context.fetch(FetchDescriptor<PetPhotoLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
    }

    @Test func deceasedMembersRejectPresentationSecurityEconomyAndSettingsWrites() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_119)
        pet.cardStyleRaw = "classic"
        let human = Human(name: "Ava")
        human.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_120)
        human.coconutBalance = 7
        human.shouldShowOnHome = false
        human.pinSalt = "test-salt"
        human.pinHash = HumanPasscodeService.hashForTesting(pin: "1234", salt: "test-salt")
        context.insert(pet)
        context.insert(human)
        try context.save()

        _ = PetCardAppearanceCommandService.enablePopout(
            pet: pet,
            imageData: Data([1, 2, 3]),
            sourceRaw: "test",
            context: context
        )
        let petUpgrade = Avatar2DUpgradeCommandService.upgradePet(pet, context: context)
        let syncResult = SettingsCommandService.syncHomeCardStackAfterActiveHumanSwitch(
            from: "",
            to: human,
            pets: [pet],
            humans: [human],
            electronicPets: [],
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            context: context
        )
        let balanceResult = SettingsCommandService.applyCoconutBalanceTest(
            amount: 99,
            human: human,
            title: "test",
            actorName: human.name,
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            projectionManager: QuestManager()
        )
        let privacyResult = try HumanPrivacyCommandService.setPrivateField(
            .weight,
            isPrivate: true,
            for: human,
            context: context
        )
        let verifyResult = HumanPasscodeService.verify("0000", for: human)
        HumanPasscodeService.clearPasscode(for: human)

        do {
            try HumanPasscodeService.setPasscode("2468", for: human)
            Issue.record("Expected deceased human passcode set to throw memberInactive")
        } catch HumanPasscodeError.memberInactive {
        } catch {
            Issue.record("Expected memberInactive, got \(error)")
        }

        #expect(pet.cardStyleRaw == "classic")
        #expect(pet.cardPopoutImageData == nil)
        #expect(!petUpgrade.didUpgrade)
        #expect(petUpgrade.failure == .memberInactive)
        #expect(!syncResult.didSyncHomeStack)
        #expect(balanceResult.amount == 7)
        #expect(balanceResult.legacyDelta == 0)
        #expect(human.coconutBalance == 7)
        #expect(privacyResult.changedFields.isEmpty)
        #expect(human.privateFields.isEmpty)
        #expect(verifyResult == .memberInactive)
        #expect(human.pinHash == HumanPasscodeService.hashForTesting(pin: "1234", salt: "test-salt"))
    }

    @Test func deceasedPetDerivedCareWrappersDoNotWrite() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_121)
        pet.currentStreak = 3
        let pottyLog = PetPottyLog(
            date: Date(),
            type: .perfectPoop,
            pet: nil,
            sharedSessionId: "shared-claim"
        )
        let ledger = CareLedgerEvent(
            subjectKind: .unknown,
            subjectId: nil,
            eventKind: .potty,
            actionType: PottyType.perfectPoop.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: pottyLog.id.uuidString
        )
        context.insert(pet)
        context.insert(pottyLog)
        context.insert(ledger)
        try context.save()

        StreakManager.refreshStreak(for: pet, context: context)
        let claim = PetPottyCommandService.claimUnknownPottyLog(pottyLog, pet: pet, context: context)

        #expect(pet.currentStreak == 3)
        #expect(pet.lastCheckInDate == nil)
        #expect(claim.updatedLedgerEventIDs.isEmpty)
        #expect(pottyLog.pet == nil)
        #expect(ledger.subjectKind == CareLedgerSubjectKind.unknown.rawValue)
        #expect(ledger.subjectId == nil)
    }

    @Test func deceasedMembersCannotMutateFamilyTasks() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Guan")
        let deceasedHuman = Human(name: "Ava")
        deceasedHuman.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_122)
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_123)
        let task = FamilyCollaborationTask(
            title: "Pet task",
            kind: .householdTask,
            relatedPetId: deceasedPet.id.uuidString,
            createdById: activeHuman.id.uuidString,
            createdByName: activeHuman.name
        )
        context.insert(activeHuman)
        context.insert(deceasedHuman)
        context.insert(deceasedPet)
        context.insert(task)
        try context.save()

        let created = FamilyTaskService.createHouseholdTask(
            title: "Assign",
            note: "",
            assignedTo: deceasedHuman,
            by: activeHuman,
            rewardCoconuts: 0,
            dueAt: nil,
            emoji: "checkmark",
            context: context
        )
        FamilyTaskService.claim(task, by: activeHuman, context: context)
        FamilyTaskService.complete(task, by: activeHuman, context: context)

        #expect(created == nil)
        #expect(task.claimedById == nil)
        #expect(task.status == .active)
        #expect(task.completedAt == nil)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).map(\.id) == [task.id])
    }

    @Test func rehydrateWritersRejectRequiredMemberScopedFactsWithoutOwners() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_900_100_000)
        let missingHumanId = UUID()

        let careResult = try DomainCareFactRehydrateWriter.insertPetCareLogIfNeeded(
            snapshot: DomainPetCareLogRehydrateSnapshot(
                id: UUID(),
                date: now,
                typeRaw: CareType.feeding.rawValue,
                amountGrams: 12,
                amountMl: 0,
                note: "remote orphan care",
                foodKindRaw: FeedFoodKind.dry.rawValue,
                treatKindRaw: nil,
                autoFeedDedupKey: "",
                sharedSessionId: "",
                petId: nil,
                executorId: nil
            ),
            source: .cloudApply,
            context: context
        )
        let medicationResult = try DomainMemberContentRehydrateWriter.insertHumanMedicationIfNeeded(
            snapshot: DomainHumanMedicationRehydrateSnapshot(
                id: UUID(),
                humanId: "",
                name: "Vitamin",
                dosage: "",
                frequencyRaw: MedicationFrequency.daily.rawValue,
                customFrequencyNote: "",
                firstDoseTime: now,
                startDate: now,
                endDate: nil,
                colorHex: "88AAFF",
                notes: "",
                isActive: true,
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )
        let ledgerResult = try DomainGeneralRehydrateWriter.upsertCoconutLedgerEntry(
            snapshot: DomainCoconutLedgerEntryRehydrateSnapshot(
                id: UUID(),
                transactionKey: "remote-orphan-ledger",
                accountKey: CoconutAccountKey.human(missingHumanId),
                ownerKindRaw: CoconutWalletOwnerKind.human.rawValue,
                ownerId: missingHumanId.uuidString,
                ownerName: "Missing",
                delta: 7,
                balanceBefore: 0,
                balanceAfter: 7,
                affectsBalance: true,
                entryKindRaw: CoconutWalletEntryKind.reward.rawValue,
                sourceRaw: CoconutWalletSource.careEvent.rawValue,
                title: "Remote reward",
                emoji: "coconut",
                actorId: nil,
                actorName: nil,
                subjectKindRaw: CareLedgerSubjectKind.human.rawValue,
                subjectId: missingHumanId.uuidString,
                sourceModelName: "",
                sourceModelId: "",
                careLedgerEventId: nil,
                metadataJSON: "",
                occurredAt: now,
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )
        let gachaResult = try DomainGeneralRehydrateWriter.upsertGachaOwnedItem(
            snapshot: DomainGachaOwnedItemRehydrateSnapshot(
                id: UUID(),
                ownerHumanId: "",
                seriesId: GachaSeriesCatalog.defaultSeriesId,
                itemId: "plush_coconut_sleepy",
                rarityRaw: GachaRarity.common.rawValue,
                isHidden: false,
                ownedCount: 1,
                firstObtainedAt: now,
                latestObtainedAt: now,
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )

        #expect(!careResult.didPersist)
        #expect(careResult.plan.disposition == .rejected(reason: "missingRequiredPet"))
        #expect(!medicationResult.didPersist)
        #expect(medicationResult.plan.disposition == .rejected(reason: "unresolvedRequiredHuman"))
        #expect(!ledgerResult.didPersist)
        #expect(ledgerResult.plan.disposition == .rejected(reason: "unresolvedRequiredHuman"))
        #expect(!gachaResult.didPersist)
        #expect(gachaResult.plan.disposition == .rejected(reason: "missingRequiredHuman"))
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaOwnedItem>()).isEmpty)
    }

    @Test func sharedCareSessionRehydrateUsesRegisteredTargetPetAsOwnerFallback() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let targetPet = Pet(name: "Nori", species: "cat")
        context.insert(targetPet)
        try context.save()
        let now = Date(timeIntervalSince1970: 1_900_200_000)

        let result = try DomainCareFactRehydrateWriter.insertSharedCareSessionIfNeeded(
            snapshot: DomainSharedCareSessionRehydrateSnapshot(
                id: UUID(),
                date: now,
                actionKindRaw: SharedCareActionKind.feeding.rawValue,
                executorId: nil,
                executorIdsRaw: "",
                sourcePetId: "",
                targetPetIds: [targetPet.id.uuidString],
                speciesRaw: "cat",
                totalAmountGrams: 30,
                totalAmountMl: 0,
                totalExpenseAmount: 0,
                expenseCategoryRaw: ExpenseCategory.other.rawValue,
                currencyCode: "EUR",
                allocationModeRaw: SharedCareAllocationMode.equal.rawValue,
                foodKindRaw: FeedFoodKind.dry.rawValue,
                stockOwnerPetId: "",
                primaryLegacyModelName: String(describing: PetCareLog.self),
                primaryLegacyModelId: UUID().uuidString,
                note: "target fallback",
                createdAt: now
            ),
            source: .cloudApply,
            context: context
        )

        #expect(result.didPersist)
        #expect(result.plan.disposition == .normalized)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).count == 1)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private final class CapturingReminderNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledNotificationIds: [String] = []

        func schedule(reminder _: Reminder) {}

        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.skippedPastDue)
        }

        func schedule(
            reminder _: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.skippedPastDue)
        }

        func pendingNotificationIds() async -> Set<String> { [] }

        func scheduleRollingWindow(reminders _: [Reminder]) {}

        func refillWindowIfNeeded(allReminders _: [Reminder]) {}

        func cancel(notificationId: String) {
            cancelledNotificationIds.append(notificationId)
        }

        func cancelAll(for _: Pet, reminders: [Reminder]) {
            cancelledNotificationIds.append(contentsOf: reminders.map(\.notificationId))
        }

        func compensate(reminders _: [Reminder]) {}
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }

    private func swiftSourcePaths(under directories: [String], rootURL: URL) throws -> [String] {
        try directories.flatMap { directory in
            let directoryURL = rootURL.appending(path: directory)
            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return [String]()
            }

            return try enumerator.compactMap { entry -> String? in
                guard let url = entry as? URL,
                      url.pathExtension == "swift" else {
                    return nil
                }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { return nil }
                return String(url.path.dropFirst(rootURL.path.count + 1))
            }
        }
    }

    private func isAchievementUnlocked(_ id: String, in achievements: [Achievement]) -> Bool {
        achievements.first(where: { $0.id == id })?.isUnlocked ?? false
    }
}
