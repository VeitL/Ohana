import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct RecurringFindingsRepairTests {
    @Test func explicitExecutorRewardEntrypointsCreditExecutorWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Executor")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        try context.save()

        let questManager = makeQuestManager()
        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: activeHuman.id.uuidString,
            questManager: questManager,
            memberIDs: [activeHuman.id.uuidString, executor.id.uuidString],
            petID: pet.id
        )

        _ = try WeightCommandService.recordPetWeight(
            pet: pet,
            weight: 4.2,
            date: Date(timeIntervalSince1970: 1_800_000_001),
            context: context,
            executorId: executor.id.uuidString,
            awardsReward: true,
            ledgerSource: .detail,
            questManager: questManager
        )
        _ = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 12,
            date: Date(timeIntervalSince1970: 1_800_000_002),
            category: .medical,
            note: "clinic",
            context: context,
            executorId: executor.id.uuidString,
            questManager: questManager
        )
        _ = try #require(PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .checkup,
                date: Date(timeIntervalSince1970: 1_800_000_003),
                name: "Checkup",
                note: "",
                vetName: "",
                cost: 0,
                expirationDate: nil,
                nextCheckupDate: nil,
                executorId: executor.id.uuidString,
                source: .detail,
                includesNameInNote: true
            ),
            context: context,
            questManager: questManager
        ))

        #expect(activeHuman.coconutBalance == 0)
        #expect(executor.coconutBalance > 0)
        let humanRewardEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
            .filter { $0.ownerKindRaw == CoconutWalletOwnerKind.human.rawValue && $0.delta > 0 }
        #expect(humanRewardEntries.isEmpty == false)
        #expect(humanRewardEntries.allSatisfy { $0.ownerId == executor.id.uuidString })
    }

    @Test func backdateRewardUsesProvidedActiveHumanSelectionForOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let selectedHuman = Human(name: "Selected")
        let pet = Pet(name: "Momo", species: "dog")
        context.insert(activeHuman)
        context.insert(selectedHuman)
        context.insert(pet)
        try context.save()

        let questManager = makeQuestManager()
        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: activeHuman.id.uuidString,
            questManager: questManager,
            memberIDs: [activeHuman.id.uuidString, selectedHuman.id.uuidString],
            petID: pet.id
        )

        let result = BackdateCheckInCommandService.award(
            action: .general(humanReward: 4, petReward: 0, emoji: "B", title: "Backdate"),
            actionKey: "backdate",
            pet: pet,
            context: context,
            questManager: questManager,
            activeHumanSelection: FixedActiveHumanSelection(id: selectedHuman.id.uuidString)
        )

        #expect(result.humanID == selectedHuman.id)
        #expect(activeHuman.coconutBalance == 0)
        #expect(selectedHuman.coconutBalance == result.humanGot)
        #expect(result.humanGot > 0)
    }

    @Test func manualMilestoneRewardAndLedgerUseCurrentActiveHuman() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "dog")
        context.insert(activeHuman)
        context.insert(pet)
        try context.save()

        let questManager = makeQuestManager()
        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: activeHuman.id.uuidString,
            questManager: questManager,
            memberIDs: [activeHuman.id.uuidString],
            petID: pet.id
        )

        let result = try PetMilestoneCommandService.createMilestone(
            input: PetMilestoneCommandInput(
                date: Date(timeIntervalSince1970: 1_800_000_004),
                title: "First beach day",
                emoji: "",
                notes: "",
                photoData: nil,
                location: ""
            ),
            pet: pet,
            context: context,
            questManager: questManager
        )

        #expect(result.milestoneIDs.count == 1)
        #expect(result.coconutDelta == 0)
        #expect(activeHuman.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func calendarWholeEventDeleteTombstonesEventAndCascadeReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = Event(
            title: "Vet",
            startDate: Date(timeIntervalSince1970: 1_800_000_005),
            eventType: EventType.medication.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: UUID().uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        _ = try CalendarEventCommandService.delete(
            event: event,
            occurrenceDate: event.startDate,
            scope: CalendarEventDeletionScope.wholeEvent,
            context: context
        )

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: event.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Reminder.self), id: reminder.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func factDeleteCommandsTombstoneAssociatedCareLedgerEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let careLog = PetCareLog(type: .feeding, pet: pet)
        let pottyLog = PetPottyLog(date: Date(timeIntervalSince1970: 1_800_000_006), type: .pee, pet: pet)
        let hygieneLog = PetHygieneLog(date: Date(timeIntervalSince1970: 1_800_000_007), type: .bath, pet: pet)
        let expenseLog = PetExpenseLog(date: Date(timeIntervalSince1970: 1_800_000_008), amount: 9, category: .medical, note: "", pet: pet)
        let weightLog = PetWeightLog(date: Date(timeIntervalSince1970: 1_800_000_009), weight: 4.3, pet: pet)
        let careLedger = ledgerEvent(model: "PetCareLog", id: careLog.id)
        let pottyLedger = ledgerEvent(model: "PetPottyLog", id: pottyLog.id)
        let hygieneLedger = ledgerEvent(model: "PetHygieneLog", id: hygieneLog.id)
        let expenseLedger = ledgerEvent(model: "PetExpenseLog", id: expenseLog.id)
        let weightLedger = ledgerEvent(model: "PetWeightLog", id: weightLog.id)
        context.insert(pet)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(expenseLog)
        context.insert(weightLog)
        context.insert(careLedger)
        context.insert(pottyLedger)
        context.insert(hygieneLedger)
        context.insert(expenseLedger)
        context.insert(weightLedger)
        try context.save()

        _ = PetCareTrackingCommandService.deleteCareLog(careLog, pet: pet, context: context)
        _ = PetPottyCommandService.deletePottyLog(pottyLog, pet: pet, context: context)
        _ = PetHygieneCommandService.delete(hygieneLog, pet: pet, context: context)
        _ = try DashboardRecordCommandService.deletePetExpense(expenseLog, pet: pet, context: context)
        _ = try DashboardRecordCommandService.deletePetWeight(weightLog, pet: pet, context: context)

        for ledger in [careLedger, pottyLedger, hygieneLedger, expenseLedger, weightLedger] {
            #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: ledger.id, context: context)?.isDeletionTombstone == true)
        }
    }

    @Test func catCareUndoTombstonesRemovedEventAndHygieneLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(pet)
        try context.save()

        let recorded = CatCareCommandService.record(
            pet: pet,
            input: CatCareCommandInput(
                actionRaw: "Scoop",
                emoji: "S",
                recordsHygiene: true,
                occurredAt: Date(timeIntervalSince1970: 1_800_000_010),
                executorId: "human-1"
            ),
            context: context
        )
        let hygieneLogID = try #require(recorded.hygieneLogID)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "PetHygieneLog" && $0.legacyModelId == hygieneLogID.uuidString
        })

        _ = CatCareCommandService.undo(
            pet: pet,
            eventID: recorded.eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )

        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: recorded.eventID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetHygieneLog.self), id: hygieneLogID, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: ledger.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func calendarCareCompletionUsesRewardPipelineAndUndoReversesGeneratedFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_020)
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "dog")
        let event = Event(
            title: "Feed Momo 42g",
            startDate: now,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: human.id.uuidString,
            questManager: makeQuestManager(),
            memberIDs: [human.id.uuidString],
            petID: pet.id
        )

        let completed = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: now,
            pets: [pet],
            context: context,
            executorId: human.id.uuidString,
            now: now
        )

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let careLedger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == String(describing: PetCareLog.self) && $0.legacyModelId == careLog.id.uuidString
        })
        let positiveEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter { $0.delta > 0 }
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).filter { $0.actionKey == "feed" }
        #expect(completed.isCompleted)
        #expect(careLog.pet?.id == pet.id)
        #expect(careLedger.source == CareLedgerSource.calendar.rawValue)
        #expect(careLedger.coconutDelta > 0)
        #expect(positiveEntries.contains { $0.ownerId == human.id.uuidString })
        #expect(budgetEvents.isEmpty == false)

        let reopened = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: now,
            pets: [pet],
            context: context,
            executorId: human.id.uuidString,
            now: now
        )

        let allEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(reopened.isCompleted == false)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).filter { $0.actionKey == "feed" }.isEmpty)
        #expect(allEntries.contains { $0.delta < 0 && $0.metadataJSON.contains("calendarCareUndo") })
        #expect(try cloudSyncState(entityName: String(describing: PetCareLog.self), id: careLog.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: careLedger.id, context: context)?.isDeletionTombstone == true)
        for event in budgetEvents {
            #expect(try cloudSyncState(entityName: String(describing: EconomyBudgetUsageEvent.self), id: event.id, context: context)?.isDeletionTombstone == true)
        }
    }

    @Test func calendarHistoricalCareCompletionMarksDirtyAtOperationDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let occurrenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let operationDate = Date(timeIntervalSince1970: 1_800_000_025)
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "dog")
        let event = Event(
            title: "Feed Momo 42g",
            startDate: occurrenceDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: human.id.uuidString,
            questManager: makeQuestManager(),
            memberIDs: [human.id.uuidString],
            petID: pet.id
        )

        let result = CalendarTaskCompletionSyncService.syncPetTask(
            event: event,
            occurrenceDate: occurrenceDate,
            isCompleted: true,
            pets: [pet],
            context: context,
            executorId: human.id.uuidString,
            operationDate: operationDate
        )

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let syncState = try #require(try cloudSyncState(entityName: String(describing: PetCareLog.self), id: careLog.id, context: context))
        #expect(result == .activeCompleted)
        #expect(careLog.date == occurrenceDate)
        #expect(syncState.lastModifiedAt == operationDate)
    }

    @Test func plannedFeedCatchUpMarksDirtyAtOperationDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let occurrenceDate = Date(timeIntervalSince1970: 1_800_000_060)
        let operationDate = occurrenceDate.addingTimeInterval(60 * 60)
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "dog")
        let event = Event(
            title: "Feed Momo 42g",
            startDate: occurrenceDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: occurrenceDate)
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: human.id.uuidString,
            questManager: makeQuestManager(),
            memberIDs: [human.id.uuidString],
            petID: pet.id
        )

        let result = CareEventService.completePlannedFeedResult(
            pet: pet,
            reminder: reminder,
            context: context,
            executorId: human.id.uuidString,
            operationDate: operationDate
        )

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let syncState = try #require(try cloudSyncState(entityName: String(describing: PetCareLog.self), id: careLog.id, context: context))
        #expect(result.didRecord)
        #expect(careLog.date == occurrenceDate)
        #expect(syncState.lastModifiedAt == operationDate)
    }

    @Test func plannedWaterCatchUpMarksDirtyAtOperationDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let occurrenceDate = Date(timeIntervalSince1970: 1_800_000_070)
        let operationDate = occurrenceDate.addingTimeInterval(60 * 60)
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "dog")
        let event = Event(
            title: "Drink water",
            startDate: occurrenceDate,
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: occurrenceDate)
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: human.id.uuidString,
            questManager: makeQuestManager(),
            memberIDs: [human.id.uuidString],
            petID: pet.id
        )

        let result = CareEventService.completePlannedWaterResult(
            pet: pet,
            reminder: reminder,
            amountMl: 120,
            context: context,
            executorId: human.id.uuidString,
            operationDate: operationDate
        )

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let syncState = try #require(try cloudSyncState(entityName: String(describing: PetCareLog.self), id: careLog.id, context: context))
        #expect(result.didRecord)
        #expect(careLog.date == occurrenceDate)
        #expect(syncState.lastModifiedAt == operationDate)
    }

    @Test func humanMedicationPlanAndDoseWritesCloudSyncDirtyState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_800_000_080)
        let scheduledTime = Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: startDate
        ) ?? startDate
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let created = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: HumanMedicationPlanCommandInput(
                name: "Vitamin D",
                dosage: "1 tablet",
                frequency: .daily,
                customFrequencyNote: "",
                doseMinutes: [8 * 60],
                weeklyWeekday: 2,
                startDate: startDate,
                endDate: nil,
                colorHex: "FF6B8A",
                visibleNotes: "",
                isActive: true,
                appLanguage: "en"
            ),
            context: context,
            scheduleReminders: false
        ))

        let medicationState = try #require(try cloudSyncState(
            entityName: String(describing: HumanMedication.self),
            id: created.medicationID,
            context: context
        ))
        let calendarEventID = try #require(created.calendarEventIDs.first)
        let event = try #require(try context.fetch(FetchDescriptor<Event>()).first { $0.id == calendarEventID })
        let eventState = try #require(try cloudSyncState(
            entityName: String(describing: Event.self),
            id: calendarEventID,
            context: context
        ))

        let dose = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: created.medicationID,
            scheduledTime: scheduledTime,
            status: .taken,
            context: context,
            now: scheduledTime
        )
        let doseLogID = try #require(dose.logID)
        let doseLogState = try #require(try cloudSyncState(
            entityName: String(describing: HumanMedicationLog.self),
            id: doseLogID,
            context: context
        ))

        #expect(medicationState.isDeletionTombstone == false)
        #expect(medicationState.lastModifiedAt == startDate)
        #expect(eventState.isDeletionTombstone == false)
        #expect(eventState.lastModifiedAt == event.startDate)
        #expect(dose.didChange == true)
        #expect(dose.recordedLedgerEvent == true)
        #expect(doseLogState.isDeletionTombstone == false)
        #expect(doseLogState.lastModifiedAt == scheduledTime)
    }

    @Test func humanMedicationActiveOnlyCommandsNoopForDeceasedHuman() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_800_000_090)
        let scheduledTime = Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: startDate
        ) ?? startDate
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        let created = try #require(HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: HumanMedicationPlanCommandInput(
                name: "Vitamin D",
                dosage: "1 tablet",
                frequency: .daily,
                customFrequencyNote: "",
                doseMinutes: [8 * 60],
                weeklyWeekday: 2,
                startDate: startDate,
                endDate: nil,
                colorHex: "FF6B8A",
                visibleNotes: "",
                isActive: true,
                appLanguage: "en"
            ),
            context: context,
            scheduleReminders: false
        ))
        let medication = try #require(try context.fetch(FetchDescriptor<HumanMedication>()).first)
        let originalCalendarEventCount = try context.fetch(FetchDescriptor<Event>()).count
        human.passedAwayDate = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        let blockedSave = HumanMedicationPlanCommandService.savePlan(
            human: human,
            editing: nil,
            input: HumanMedicationPlanCommandInput(
                name: "New medicine",
                dosage: "2 tablets",
                frequency: .daily,
                customFrequencyNote: "",
                doseMinutes: [9 * 60],
                weeklyWeekday: 2,
                startDate: startDate,
                endDate: nil,
                colorHex: "00AEEF",
                visibleNotes: "",
                isActive: true,
                appLanguage: "en"
            ),
            context: context,
            scheduleReminders: false
        )
        let activation = HumanMedicationPlanCommandService.setPlanActive(
            human: human,
            medication: medication,
            isActive: false,
            appLanguage: "en",
            context: context,
            scheduleReminders: false
        )
        let dose = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: created.medicationID,
            scheduledTime: scheduledTime,
            status: .taken,
            context: context,
            now: scheduledTime
        )
        let deletion = HumanMedicationPlanCommandService.deletePlan(
            human: human,
            medication: medication,
            context: context,
            scheduleReminders: false
        )

        #expect(blockedSave == nil)
        #expect(activation.didChange == false)
        #expect(dose.didChange == false)
        #expect(dose.recordedLedgerEvent == false)
        #expect(deletion.didChange == false)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == originalCalendarEventCount)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(medication.isActive == true)
    }

    @Test func reminderDedupeTombstonesRemovedDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let scheduledAt = Date(timeIntervalSince1970: 1_800_000_026)
        let event = Event(
            title: "Drink water",
            startDate: scheduledAt,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: UUID().uuidString
        )
        let first = Reminder(event: event, scheduledAt: scheduledAt)
        let duplicate = Reminder(event: event, scheduledAt: scheduledAt.addingTimeInterval(10))
        context.insert(event)
        context.insert(first)
        context.insert(duplicate)
        try context.save()

        let kept = ReminderSchedulingService.deduplicate(reminders: [duplicate, first], context: context)

        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(kept.map(\.id) == [first.id])
        #expect(reminders.count == 1)
        #expect(reminders.first?.id == first.id)
        #expect(try cloudSyncState(entityName: String(describing: Reminder.self), id: duplicate.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func notificationCompleteForDailyCareReminderRecordsCareFactAndReward() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_030)
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "dog")
        let event = Event(
            title: "Drink water",
            startDate: now,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: now)
        context.insert(human)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        prepareEconomyDefaults(
            activeHumanID: human.id.uuidString,
            questManager: makeQuestManager(),
            memberIDs: [human.id.uuidString],
            petID: pet.id
        )

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "reminderId": reminder.id.uuidString
            ],
            currentActiveHumanId: human.id.uuidString,
            context: context
        )

        let careLog = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let positiveEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter { $0.delta > 0 }
        #expect(result == .completed)
        #expect(reminder.statusEnum == .completed)
        #expect(event.isOccurrenceMarkedComplete(on: now))
        #expect(careLog.careType == .watering)
        #expect(careLog.pet?.id == pet.id)
        #expect(positiveEntries.contains { $0.ownerId == human.id.uuidString })
    }

    @Test func symptomAndHeatDeletesWriteTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "dog")
        let symptom = SymptomLog(
            date: Date(timeIntervalSince1970: 1_800_000_040),
            category: .skin,
            symptomName: "itchy",
            severity: .mild,
            pet: pet
        )
        let heat = HeatCycleLog(
            startDate: Date(timeIntervalSince1970: 1_800_000_041),
            status: .estrus,
            pet: pet
        )
        context.insert(pet)
        context.insert(symptom)
        context.insert(heat)
        try context.save()

        _ = PetHealthDeleteCommandService.deleteSymptomLog(symptom, pet: pet, context: context)
        _ = PetHealthDeleteCommandService.deleteHeatCycleLog(heat, pet: pet, context: context)

        #expect(try context.fetch(FetchDescriptor<SymptomLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HeatCycleLog>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: SymptomLog.self), id: symptom.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: HeatCycleLog.self), id: heat.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func carePlanAndWaterPlanDeletesTombstoneEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "fish")
        context.insert(pet)
        try context.save()
        let start = Date(timeIntervalSince1970: 1_800_000_050)

        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: context,
            intervalDays: 7,
            enabled: true,
            cycleAnchor: start
        )
        let carePlanEvent = try #require(try context.fetch(FetchDescriptor<Event>()).first)
        CarePlanCalendarSync.syncWaterChangePlan(
            pet: pet,
            context: context,
            intervalDays: 7,
            enabled: false,
            cycleAnchor: start
        )

        let waterPlanEvent = Event(
            title: "Momo drink",
            startDate: start,
            eventType: EventType.daily.rawValue,
            relatedEntityType: WaterPlanWriter.entityType,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: waterPlanEvent, scheduledAt: start)
        context.insert(waterPlanEvent)
        context.insert(reminder)
        try context.save()
        WaterPlanWriter.deletePlan(pet: pet, allEvents: [waterPlanEvent], context: context)

        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: carePlanEvent.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: waterPlanEvent.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Reminder.self), id: reminder.id, context: context)?.isDeletionTombstone == true)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeQuestManager() -> QuestManager {
        let questManager = QuestManager(wallet: SwiftDataCoconutWalletManager())
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        return questManager
    }

    private func prepareEconomyDefaults(
        activeHumanID: String,
        questManager: QuestManager,
        memberIDs: [String],
        petID: UUID
    ) {
        UserDefaults.standard.set(activeHumanID, forKey: "currentActiveHumanId")
        UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        UserDefaults.standard.removeObject(forKey: "shop_boostDoubleActive")
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        let objectKeys = ["pet.\(petID.uuidString)"]
        for memberID in memberIDs {
            EconomyDailyBudgetStore.reset(
                householdKey: CoconutEconomyPolicyV2.householdBudgetKey(),
                memberKey: memberID,
                careObjectKeys: objectKeys
            )
        }
    }

    private func ledgerEvent(model: String, id: UUID) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 1_800_000_011),
            subjectKind: .pet,
            subjectId: UUID().uuidString,
            eventKind: .unknown,
            actionType: "delete-test",
            legacyModelName: model,
            legacyModelId: id.uuidString
        )
    }

    private func cloudSyncState(entityName: String, id: UUID, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == entityName && $0.localRecordId == id.uuidString.lowercased()
        }
    }
}

private struct EconomyDefaultsState {
    let activeHumanID: Any?
    let cooldownLogs: Any?
    let boostDouble: Any?

    static func capture() -> EconomyDefaultsState {
        let defaults = UserDefaults.standard
        return EconomyDefaultsState(
            activeHumanID: defaults.object(forKey: "currentActiveHumanId"),
            cooldownLogs: defaults.object(forKey: QuestManager.Keys.cooldownLogs),
            boostDouble: defaults.object(forKey: "shop_boostDoubleActive")
        )
    }

    func restore() {
        restore(activeHumanID, key: "currentActiveHumanId")
        restore(cooldownLogs, key: QuestManager.Keys.cooldownLogs)
        restore(boostDouble, key: "shop_boostDoubleActive")
    }

    private func restore(_ value: Any?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private struct FixedActiveHumanSelection: ActiveHumanSelecting {
    let id: String?
    var currentHumanId: String? { id }
    var currentHumanIdRaw: String { id ?? "" }
}
