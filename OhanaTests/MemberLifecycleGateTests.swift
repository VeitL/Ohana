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
