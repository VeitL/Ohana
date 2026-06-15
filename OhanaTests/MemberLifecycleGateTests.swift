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

        let petPlan = CalendarEventPlanCommandService.createEvent(
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
        let humanPlan = CalendarEventPlanCommandService.createEvent(
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
        let deceasedAssigneePlan = CalendarEventPlanCommandService.createEvent(
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

        let petPlan = CalendarEventPlanCommandService.createEvent(
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
        let humanPlan = CalendarEventPlanCommandService.createEvent(
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

        let petPlan = CalendarEventPlanCommandService.createEvent(
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
        let humanPlan = CalendarEventPlanCommandService.createEvent(
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
        let invalidPetPlan = CalendarEventPlanCommandService.createEvent(
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
        let missingAssigneePlan = CalendarEventPlanCommandService.createEvent(
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
        let result = FeedingPlanWriter.replacePlan(
            pet: pet,
            draft: draft,
            allEvents: [],
            context: context,
            now: now
        )
        _ = FeedingPlanWriter.saveFoodPurchase(
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
        _ = WaterPlanWriter.replacePlan(
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
        let plan = executor.saveWaterPlan(pet: pet, targets: [pet], times: [now], count: 1, allEvents: [])
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

        let result = CalendarEventPlanCommandService.createEvent(
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
            rewardCoconuts: 0,
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
        let result = try #require(CalendarEventPlanCommandService.createEvent(
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

        let completion = CalendarEventCommandService.toggleCompletion(
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
            title: "用药 Drops",
            startDate: scheduledAt,
            eventType: EventType.medication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
        let otherMedicationEvent = Event(
            title: "用药 Vitamin",
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

        let result = PetPhotoAlbumCommandService.createPhotos(
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
        let privacyResult = HumanPrivacyCommandService.setPrivateField(
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

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV72.models)
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
}
