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
            relatedEntityType: MedicationEventLink.petMedicationPlan,
            relatedEntityId: petMedication.id.uuidString
        )
        let humanMedicationEvent = Event(
            title: "Human medication",
            relatedEntityType: MedicationEventLink.humanMedicationPlan,
            relatedEntityId: humanMedication.id.uuidString
        )
        let insuranceEvent = Event(
            title: "Insurance",
            relatedEntityType: "pet_insurance",
            relatedEntityId: insurance.id.uuidString
        )
        let humanNote = Event(
            title: "Human note",
            relatedEntityType: "human_note",
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
        let reminderOnly = Reminder(event: nil, scheduledAt: Date(timeIntervalSince1970: 1_800_003_000))

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
        #expect(MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(reminderOnly, activePets: [], activeHumans: []))
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
}
