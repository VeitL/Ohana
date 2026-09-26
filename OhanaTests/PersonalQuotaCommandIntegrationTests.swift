import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PersonalQuotaCommandIntegrationTests {
    @Test func usageSnapshotCountsOnlyActiveUserPlansAndExemptsGeneratedOrInformationalEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let activePet = Pet(name: "Active", species: "dog", breed: "Mixed")
        context.insert(activePet)
        let memorialPet = Pet(name: "Memorial", species: "cat", breed: "Mixed")
        memorialPet.passedAwayDate = Date()
        context.insert(memorialPet)
        context.insert(Human(name: "Alex"))
        context.insert(Plant(name: "Fern"))
        let archivedPlant = Plant(name: "Archived")
        archivedPlant.archivedAt = Date()
        context.insert(archivedPlant)

        let ordinaryPlan = Event(title: "Walk", eventType: EventType.daily.rawValue)
        context.insert(ordinaryPlan)
        context.insert(Reminder(event: ordinaryPlan, scheduledAt: Date().addingTimeInterval(3600)))
        let healthPlan = Event(title: "Medication", eventType: EventType.medication.rawValue)
        healthPlan.recurrenceDays = 1
        context.insert(healthPlan)
        for meal in 0 ..< 2 {
            let feedingPlan = Event(
                title: "Meal \(meal)",
                eventType: EventType.foodChange.rawValue,
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: activePet.id.uuidString
            )
            feedingPlan.recurrenceDays = 1
            feedingPlan.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
            context.insert(feedingPlan)
        }
        context.insert(Event(title: "Birthday", eventType: EventType.birthday.rawValue))
        let memberBirthday = Event(
            title: "Member birthday",
            eventType: EventType.birthday.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: activePet.id.uuidString
        )
        memberBirthday.recurrenceDays = 365
        context.insert(memberBirthday)
        let stockProjection = Event(
            title: "Food stock",
            startDate: Date().addingTimeInterval(3600),
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petFoodStock,
            relatedEntityId: activePet.id.uuidString
        )
        context.insert(stockProjection)
        context.insert(Reminder(event: stockProjection, scheduledAt: stockProjection.startDate))
        context.insert(Event(title: "Watered plant", eventType: EventType.watering.rawValue))
        context.insert(Event(
            title: "Future note without reminder",
            startDate: Date().addingTimeInterval(86400),
            eventType: EventType.daily.rawValue
        ))
        let completed = Event(title: "Done", eventType: EventType.task.rawValue)
        completed.isCompleted = true
        context.insert(completed)
        try context.save()

        let snapshot = try PersonalUsageSnapshotReader.snapshot(context: context)

        #expect(snapshot.activePetCount == 1)
        #expect(snapshot.activeHumanCount == 1)
        #expect(snapshot.activePlantCount == 1)
        #expect(snapshot.ordinaryActivePlanCount == 2)
        #expect(snapshot.healthCriticalActivePlanCount == 1)
    }

    @Test func freePlantCreationStopsAtFiveWhilePersonalCanContinue() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0 ..< PersonalFreeLimits.current.activePlants {
            context.insert(Plant(name: "Plant \(index)"))
        }
        try context.save()

        let freeResult = PlantCreationCommandService.createPlant(
            input: plantInput(name: "Sixth"),
            context: context,
            personalAccessLevel: .free,
            scheduleNotifications: false
        )

        #expect(!freeResult.didPersist)
        #expect(freeResult.personalDenial?.resource == .activePlant)
        #expect(try context.fetchCount(FetchDescriptor<Plant>()) == 5)

        let personalResult = PlantCreationCommandService.createPlant(
            input: plantInput(name: "Sixth"),
            context: context,
            personalAccessLevel: .personal,
            scheduleNotifications: false
        )

        #expect(personalResult.didPersist)
        #expect(try context.fetchCount(FetchDescriptor<Plant>()) == 6)
        #expect(try PersonalUsageSnapshotReader.snapshot(context: context).ordinaryActivePlanCount == 0)
    }

    @Test func petCreationPreflightRunsBeforeTheDraftAndUsesActivePetSemantics() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activePet = Pet(name: "Active", species: "dog", breed: "Mixed")
        context.insert(activePet)
        let memorialPet = Pet(name: "Memorial", species: "cat", breed: "Mixed")
        memorialPet.passedAwayDate = Date()
        context.insert(memorialPet)
        try context.save()

        var accessLevel = PersonalAccessLevel.free
        let service = MemberCreationService(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(),
            questManager: TestQuestManagerProjection.manager,
            personalAccessLevel: { accessLevel }
        )

        let freePreflight = try service.creationAccessDenial(kind: .pet, context: context)
        let freeDenial = try #require(freePreflight)
        #expect(freeDenial.resource == .activePet)
        #expect(freeDenial.currentCount == 1)
        #expect(freeDenial.attemptedCount == 2)
        #expect(!freeDenial.preservesGrandfatheredData)

        accessLevel = .personal
        #expect(try service.creationAccessDenial(kind: .pet, context: context) == nil)

        accessLevel = .free
        activePet.passedAwayDate = Date()
        try context.save()
        #expect(try service.creationAccessDenial(kind: .pet, context: context) == nil)

        activePet.passedAwayDate = nil
        memorialPet.passedAwayDate = nil
        try context.save()
        let grandfatheredPreflight = try service.creationAccessDenial(kind: .pet, context: context)
        let grandfatheredDenial = try #require(grandfatheredPreflight)
        #expect(grandfatheredDenial.currentCount == 2)
        #expect(grandfatheredDenial.preservesGrandfatheredData)
    }

    @Test func liveMemberCreationBoundaryRejectsSecondFreePetWithoutChangingExistingData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Pet(name: "First", species: "dog", breed: "Mixed"))
        try context.save()

        var draft = MemberCreationDraft(kind: .pet)
        draft.name = "Second"
        draft.species = "cat"
        draft.breed = "Mixed"
        draft.petGender = "girl"

        let service = MemberCreationService(
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService(),
            revisions: SharedDomainRevisionPublisher(),
            questManager: TestQuestManagerProjection.manager,
            personalAccessLevel: { .free }
        )

        do {
            _ = try service.save(
                draft: draft,
                existingPets: [],
                existingHumans: [],
                context: context,
                countryCode: "DE"
            )
            Issue.record("Expected a second active Free pet to require Personal")
        } catch let MemberCreationError.personalUpgradeRequired(denial) {
            #expect(denial.resource == .activePet)
            #expect(denial.currentCount == 1)
        }

        #expect(try context.fetchCount(FetchDescriptor<Pet>()) == 1)
    }

    @Test func freeCalendarCreationStopsAtThreeOrdinaryPlansButAllowsHealthCriticalPlan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var existingPlans: [Event] = []
        for index in 0 ..< PersonalFreeLimits.current.ordinaryActivePlans {
            let event = Event(title: "Plan \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
            existingPlans.append(event)
        }
        let calendarNote = Event(title: "Note", eventType: EventType.daily.rawValue)
        context.insert(calendarNote)
        try context.save()

        do {
            _ = try CalendarEventPlanCommandService.createEvent(
                input: eventInput(title: "Fourth", eventType: .daily),
                context: context,
                personalAccessLevel: .free,
                scheduleNotifications: false
            )
            Issue.record("Expected the fourth ordinary Free plan to require Personal")
        } catch let CalendarCommandError.personalUpgradeRequired(denial) {
            #expect(denial.resource == .ordinaryActivePlan)
            #expect(denial.limit == 3)
        }

        let editedExisting = try CalendarEventPlanCommandService.updateEvent(
            event: existingPlans[0],
            input: eventInput(title: "Edited existing", eventType: .task),
            context: context,
            personalAccessLevel: .free,
            scheduleNotifications: false
        )
        #expect(editedExisting != nil)

        do {
            _ = try CalendarEventPlanCommandService.updateEvent(
                event: calendarNote,
                input: eventInput(title: "Turn note into a plan", eventType: .daily),
                context: context,
                personalAccessLevel: .free,
                scheduleNotifications: false
            )
            Issue.record("Expected a non-plan to plan edit to require Personal at the Free limit")
        } catch let CalendarCommandError.personalUpgradeRequired(denial) {
            #expect(denial.resource == .ordinaryActivePlan)
        }

        let healthResult = try CalendarEventPlanCommandService.createEvent(
            input: eventInput(title: "Medication", eventType: .medication),
            context: context,
            personalAccessLevel: .free,
            scheduleNotifications: false
        )
        #expect(healthResult != nil)
    }

    @Test func freeReactivationDoesNotUseArchivingOrMemorialAsAQuotaLoophole() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Pet(name: "Active", species: "dog", breed: "Mixed"))
        let memorial = Pet(name: "Memorial", species: "cat", breed: "Mixed")
        memorial.passedAwayDate = Date()
        context.insert(memorial)
        for index in 0 ..< PersonalFreeLimits.current.activePlants {
            context.insert(Plant(name: "Active Plant \(index)"))
        }
        let archived = Plant(name: "Archived")
        archived.archivedAt = Date()
        context.insert(archived)
        try context.save()

        let petResult = MemberLifecycleCommandService.undoPetPassedAway(
            memorial,
            context: context,
            personalAccessLevel: .free
        )
        let plantResult = MemberLifecycleCommandService.restorePlant(
            archived,
            context: context,
            personalAccessLevel: .free
        )

        try expectDenial(
            petResult,
            resource: .activePet,
            currentCount: 1,
            attemptedCount: 2,
            limit: PersonalFreeLimits.current.activePets
        )
        try expectDenial(
            plantResult,
            resource: .activePlant,
            currentCount: 5,
            attemptedCount: 6,
            limit: PersonalFreeLimits.current.activePlants
        )
        #expect(!petResult.didWrite)
        #expect(!plantResult.didWrite)
        #expect(memorial.passedAwayDate != nil)
        #expect(archived.archivedAt != nil)
    }

    @Test func freeHumanReactivationAtLimitIsDeniedWithoutChangingMemorialState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0 ..< PersonalFreeLimits.current.activeHumans {
            context.insert(Human(name: "Active Human \(index)"))
        }
        let passedAwayAt = Date(timeIntervalSince1970: 1_782_345_600)
        let memorial = Human(name: "Memorial Human")
        memorial.passedAwayDate = passedAwayAt
        context.insert(memorial)
        try context.save()

        let result = MemberLifecycleCommandService.undoHumanPassedAway(
            memorial,
            context: context,
            personalAccessLevel: .free
        )

        try expectDenial(
            result,
            resource: .activeHuman,
            currentCount: 2,
            attemptedCount: 3,
            limit: PersonalFreeLimits.current.activeHumans
        )
        #expect(!result.didWrite)
        #expect(memorial.passedAwayDate == passedAwayAt)
        #expect(try PersonalUsageSnapshotReader.snapshot(context: context).activeHumanCount == 2)
    }

    @Test func freeReactivationSucceedsThroughEachLifecycleBoundaryAtTheInclusiveLimit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let memorialPet = Pet(name: "Memorial Pet", species: "cat", breed: "Mixed")
        memorialPet.passedAwayDate = Date(timeIntervalSince1970: 1_782_345_600)
        context.insert(memorialPet)
        context.insert(Human(name: "Active Human"))
        let memorialHuman = Human(name: "Memorial Human")
        memorialHuman.passedAwayDate = Date(timeIntervalSince1970: 1_782_345_601)
        context.insert(memorialHuman)
        for index in 0 ..< (PersonalFreeLimits.current.activePlants - 1) {
            context.insert(Plant(name: "Active Plant \(index)"))
        }
        let archivedPlant = Plant(name: "Archived Plant")
        archivedPlant.archivedAt = Date(timeIntervalSince1970: 1_782_345_602)
        context.insert(archivedPlant)
        try context.save()

        let petResult = MemberLifecycleCommandService.undoPetPassedAway(
            memorialPet,
            context: context,
            personalAccessLevel: .free
        )
        let humanResult = MemberLifecycleCommandService.undoHumanPassedAway(
            memorialHuman,
            context: context,
            personalAccessLevel: .free
        )
        let plantResult = MemberLifecycleCommandService.restorePlant(
            archivedPlant,
            context: context,
            personalAccessLevel: .free
        )

        #expect(petResult.personalDenial == nil)
        #expect(humanResult.personalDenial == nil)
        #expect(plantResult.personalDenial == nil)
        #expect(petResult.didWrite && petResult.action == "passed.undo")
        #expect(humanResult.didWrite && humanResult.action == "passed.undo")
        #expect(plantResult.didWrite && plantResult.action == "archive.restore")
        #expect(memorialPet.passedAwayDate == nil)
        #expect(memorialHuman.passedAwayDate == nil)
        #expect(archivedPlant.archivedAt == nil)

        let usage = try PersonalUsageSnapshotReader.snapshot(context: context)
        #expect(usage.activePetCount == PersonalFreeLimits.current.activePets)
        #expect(usage.activeHumanCount == PersonalFreeLimits.current.activeHumans)
        #expect(usage.activePlantCount == PersonalFreeLimits.current.activePlants)
    }

    @Test func personalReactivationSucceedsForPetsHumansAndPlantsBeyondFreeLimits() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0 ... PersonalFreeLimits.current.activePets {
            context.insert(Pet(name: "Active Pet \(index)", species: "dog", breed: "Mixed"))
        }
        let memorialPet = Pet(name: "Memorial Pet", species: "cat", breed: "Mixed")
        memorialPet.passedAwayDate = Date(timeIntervalSince1970: 1_782_345_600)
        context.insert(memorialPet)
        for index in 0 ... PersonalFreeLimits.current.activeHumans {
            context.insert(Human(name: "Active Human \(index)"))
        }
        let memorialHuman = Human(name: "Memorial Human")
        memorialHuman.passedAwayDate = Date(timeIntervalSince1970: 1_782_345_601)
        context.insert(memorialHuman)
        for index in 0 ... PersonalFreeLimits.current.activePlants {
            context.insert(Plant(name: "Active Plant \(index)"))
        }
        let archivedPlant = Plant(name: "Archived Plant")
        archivedPlant.archivedAt = Date(timeIntervalSince1970: 1_782_345_602)
        context.insert(archivedPlant)
        try context.save()

        let petResult = MemberLifecycleCommandService.undoPetPassedAway(
            memorialPet,
            context: context,
            personalAccessLevel: .personal
        )
        let humanResult = MemberLifecycleCommandService.undoHumanPassedAway(
            memorialHuman,
            context: context,
            personalAccessLevel: .personal
        )
        let plantResult = MemberLifecycleCommandService.restorePlant(
            archivedPlant,
            context: context,
            personalAccessLevel: .personal
        )

        #expect(petResult.didWrite && petResult.personalDenial == nil)
        #expect(humanResult.didWrite && humanResult.personalDenial == nil)
        #expect(plantResult.didWrite && plantResult.personalDenial == nil)
        #expect(memorialPet.passedAwayDate == nil)
        #expect(memorialHuman.passedAwayDate == nil)
        #expect(archivedPlant.archivedAt == nil)

        let usage = try PersonalUsageSnapshotReader.snapshot(context: context)
        #expect(usage.activePetCount == PersonalFreeLimits.current.activePets + 2)
        #expect(usage.activeHumanCount == PersonalFreeLimits.current.activeHumans + 2)
        #expect(usage.activePlantCount == PersonalFreeLimits.current.activePlants + 2)
    }

    @Test func memberCommandExecutorHonorsFreeReactivationLimitsWithoutPublishingRevisions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0 ..< PersonalFreeLimits.current.activePets {
            context.insert(Pet(name: "Active Pet \(index)", species: "dog", breed: "Mixed"))
        }
        let memorialPet = Pet(name: "Memorial Pet", species: "cat", breed: "Mixed")
        memorialPet.passedAwayDate = Date(timeIntervalSince1970: 1_782_345_600)
        context.insert(memorialPet)
        for index in 0 ..< PersonalFreeLimits.current.activeHumans {
            context.insert(Human(name: "Active Human \(index)"))
        }
        let memorialHuman = Human(name: "Memorial Human")
        memorialHuman.passedAwayDate = Date(timeIntervalSince1970: 1_782_345_601)
        context.insert(memorialHuman)
        for index in 0 ..< PersonalFreeLimits.current.activePlants {
            context.insert(Plant(name: "Active Plant \(index)"))
        }
        let archivedPlant = Plant(name: "Archived Plant")
        archivedPlant.archivedAt = Date(timeIntervalSince1970: 1_782_345_602)
        context.insert(archivedPlant)
        try context.save()

        let revisionCenter = ReadModelRevisionCenter()
        let initialRevision = revisionCenter.homeRevision
        let executor = MemberCommandExecutor(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: TestQuestManagerProjection.manager,
            personalAccessLevel: .free
        )

        let petResult = executor.undoPetPassedAway(memorialPet, note: "test.personal.pet.undo")
        let humanResult = executor.undoHumanPassedAway(memorialHuman, note: "test.personal.human.undo")
        let plantResult = executor.restorePlant(archivedPlant, note: "test.personal.plant.restore")

        try expectDenial(
            petResult,
            resource: .activePet,
            currentCount: 1,
            attemptedCount: 2,
            limit: PersonalFreeLimits.current.activePets
        )
        try expectDenial(
            humanResult,
            resource: .activeHuman,
            currentCount: 2,
            attemptedCount: 3,
            limit: PersonalFreeLimits.current.activeHumans
        )
        try expectDenial(
            plantResult,
            resource: .activePlant,
            currentCount: 5,
            attemptedCount: 6,
            limit: PersonalFreeLimits.current.activePlants
        )
        #expect(memorialPet.passedAwayDate != nil)
        #expect(memorialHuman.passedAwayDate != nil)
        #expect(archivedPlant.archivedAt != nil)
        #expect(revisionCenter.lastMutation == nil)
        #expect(revisionCenter.homeRevision == initialRevision)
    }

    @Test func freeReminderReactivationCannotCreateAFourthOrdinaryPlan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0 ..< PersonalFreeLimits.current.ordinaryActivePlans {
            let event = Event(title: "Active \(index)", eventType: EventType.task.rawValue)
            event.recurrenceDays = 7
            context.insert(event)
        }
        let completedEvent = Event(
            title: "Completed one-off",
            startDate: Date().addingTimeInterval(3600),
            eventType: EventType.daily.rawValue
        )
        completedEvent.isCompleted = true
        let completedReminder = Reminder(event: completedEvent, scheduledAt: completedEvent.startDate)
        completedReminder.statusEnum = .completed
        completedReminder.completedAt = Date()
        context.insert(completedEvent)
        context.insert(completedReminder)
        try context.save()

        do {
            _ = try CalendarEventCommandService.toggleCompletion(
                event: completedEvent,
                occurrenceDate: completedEvent.startDate,
                pets: [],
                context: context,
                executorId: nil,
                options: CalendarEventCompletionOptions(
                    reminderCompletion: ReminderCompletionService(),
                    personalAccessLevel: .free
                )
            )
            Issue.record("Expected ordinary-plan reactivation to require Personal")
        } catch let PersonalPlanQuotaCommandError.personalUpgradeRequired(denial) {
            #expect(denial.resource == .ordinaryActivePlan)
            #expect(denial.currentCount == 3)
            #expect(denial.attemptedCount == 4)
        }

        #expect(completedEvent.isCompleted)
        #expect(completedReminder.statusEnum == .completed)
    }

    private func plantInput(name: String) -> PlantCreationCommandInput {
        PlantCreationCommandInput(
            name: name,
            species: "Fern",
            location: "Home",
            avatarEmoji: "🌿",
            wateringIntervalDays: 7,
            fertilizingIntervalDays: 30
        )
    }

    private func eventInput(title: String, eventType: EventType) -> CalendarEventPlanCommandInput {
        CalendarEventPlanCommandInput(
            title: title,
            startDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            eventType: eventType,
            relatedEntityType: "",
            relatedEntityId: "",
            recurrenceDays: 7,
            recurrenceEndDate: nil,
            reminderLeadMinutes: nil,
            assigneeId: nil
        )
    }

    private func expectDenial(
        _ result: MemberLifecycleCommandResult,
        resource: PersonalLimitedResource,
        currentCount: Int,
        attemptedCount: Int,
        limit: Int
    ) throws {
        let denial = try #require(result.personalDenial)
        #expect(denial.resource == resource)
        #expect(denial.currentCount == currentCount)
        #expect(denial.attemptedCount == attemptedCount)
        #expect(denial.limit == limit)
        #expect(!denial.preservesGrandfatheredData)
        #expect(!result.didWrite)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
