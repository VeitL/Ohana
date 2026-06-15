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

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV72.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
