import Foundation
import MapKit
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct CareCompletionChokepointCharacterizationTests {
    @Test func medicationDoseWritesFactRewardLedgerBudgetAndReminderForExecutor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Executor")
        let pet = Pet(name: "Momo", species: "cat")
        let medication = PetMedication(name: "Antibiotic", dosage: "1 pill", frequency: .daily, pet: pet)
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        context.insert(medication)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, executor], pets: [pet])
        let questManager = makeQuestManager()
        let medicationReminders = MedicationReminderManagerSpy()

        let event = PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: context,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            executorId: executor.id.uuidString,
            medicationReminders: medicationReminders
        )

        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.legacyModelName == "Event" && $0.legacyModelId == event.id.uuidString
        })
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(event.eventType == EventType.petMedicationDose.rawValue)
        #expect(event.assigneeId == executor.id.uuidString)
        #expect(ledger.eventKind == CareLedgerEventKind.medication.rawValue)
        #expect(ledger.actorId == executor.id.uuidString)
        #expect(ledger.coconutDelta > 0)
        #expect(walletEntries.contains { $0.ownerId == executor.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != activeHuman.id.uuidString })
        #expect(budgetEvents.contains { $0.memberKey == executor.id.uuidString })
        #expect(medicationReminders.recordedMedicationIDs == [medication.id])
    }

    @Test func medicationDoseRejectsDeceasedConfirmedExecutorWithoutFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Former caretaker")
        executor.passedAwayDate = Date(timeIntervalSince1970: 1000)
        let pet = Pet(name: "Momo", species: "cat")
        let medication = PetMedication(
            name: "Antibiotic",
            dosage: "1 pill",
            frequency: .daily,
            remainingAmount: 5,
            pet: pet
        )
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        context.insert(medication)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, executor], pets: [pet])
        let medicationReminders = MedicationReminderManagerSpy()

        let result = PetMedicationDoseLogging.recordDoseResult(
            medication: medication,
            pet: pet,
            modelContext: context,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: makeQuestManager()),
            executorId: executor.id.uuidString,
            medicationReminders: medicationReminders
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(!result.didRecord)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(walletEntries.isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(medication.remainingAmount == 5)
        #expect(medicationReminders.recordedMedicationIDs.isEmpty)
    }

    @Test func medicationDoseCommandExecutorRejectsDeceasedConfirmedExecutor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Former caretaker")
        executor.passedAwayDate = Date(timeIntervalSince1970: 1000)
        let pet = Pet(name: "Momo", species: "cat")
        let medication = PetMedication(
            name: "Antibiotic",
            dosage: "1 pill",
            frequency: .daily,
            remainingAmount: 5,
            pet: pet
        )
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        context.insert(medication)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, executor], pets: [pet])
        let revisionCenter = ReadModelRevisionCenter()
        let medicationReminders = MedicationReminderManagerSpy()
        let commandExecutor = PetMedicationCommandExecutor(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: makeQuestManager(),
            medicationReminders: medicationReminders
        )

        let result = commandExecutor.recordDose(
            medication: medication,
            pet: pet,
            awardCoconut: true,
            executorId: executor.id.uuidString,
            note: "test.pet.medication.dose.fallback"
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(!result.didRecord)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(walletEntries.isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(medication.remainingAmount == 5)
        #expect(medicationReminders.recordedMedicationIDs.isEmpty)
    }

    @Test func singleWalkPersistsWalkFactBeforeWalletRewardAndLinksPottyMarkers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Walker")
        let pet = Pet(name: "Piper", species: "dog")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])
        let wallet = WalkFactOrderAssertingWallet()
        let revisionCenter = ReadModelRevisionCenter()
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let questManager = QuestManager(wallet: wallet, revisions: revisions)
        let location = FakeWalkLocationManager()
        location.totalDistance = 900
        let manager = PetWalkingManager(locationManager: location, questManager: questManager, revisions: revisions)

        manager.start(pet: pet)
        manager.addPoop(type: .perfectPoop)
        let stopSummary = manager.stop(modelContext: context)

        let walkLog = try #require(try context.fetch(FetchDescriptor<PetWalkLog>()).first)
        let pottyLog = try #require(try context.fetch(FetchDescriptor<PetPottyLog>()).first)
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(wallet.factCountSeenDuringReward > 0)
        #expect(stopSummary.walkLogID == walkLog.id)
        #expect(stopSummary.coconutDelta > 0)
        #expect(stopSummary.walkCoconutDelta > 0)
        #expect(stopSummary.pottyCoconutDelta > 0)
        #expect(walkLog.distanceMeters == 900)
        #expect(walkLog.coconutsEarned > 0)
        #expect(pottyLog.walkLogId == walkLog.id.uuidString)
        #expect(ledgers.contains { $0.eventKind == CareLedgerEventKind.walk.rawValue && $0.legacyModelId == walkLog.id.uuidString })
        #expect(ledgers.contains { $0.eventKind == CareLedgerEventKind.potty.rawValue && $0.legacyModelId == pottyLog.id.uuidString })
        #expect(budgetEvents.contains { $0.actionKey == "walk" })
        #expect(budgetEvents.contains { $0.actionKey == "potty" })
        #expect(revisionCenter.lastMutation?.command == .petWalkCompletion(petID: pet.id))
        #expect(PetCareCompletionTrigger.resolve(try #require(revisionCenter.lastMutation)) == .init(petID: pet.id, kind: .walk))
    }

    @Test func singleWalkWritesFactsForDeceasedExecutorThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Former walker")
        executor.passedAwayDate = Date(timeIntervalSince1970: 1000)
        let pet = Pet(name: "Piper", species: "dog")
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, executor], pets: [pet])
        let location = FakeWalkLocationManager()
        location.totalDistance = 900
        let manager = PetWalkingManager(locationManager: location, questManager: makeQuestManager())

        manager.start(pet: pet)
        manager.addPoop(type: .perfectPoop)
        manager.stop(modelContext: context)

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != executor.id.uuidString })
        #expect(!(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())).isEmpty)
    }

    @Test func sharedWalkWritesSessionChildFactsLedgerRewardAndBudgetOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Walker")
        let first = Pet(name: "Piper", species: "dog")
        let second = Pet(name: "Rex", species: "dog")
        context.insert(human)
        context.insert(first)
        context.insert(second)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [first, second])

        let result = CareEventService.recordSharedWalk(
            sourcePet: first,
            targets: [first, second],
            distanceMeters: 900,
            endDate: Date(timeIntervalSince1970: 2000),
            context: context,
            executorId: human.id.uuidString,
            startDate: Date(timeIntervalSince1970: 1800)
        )

        let session = try #require(try context.fetch(FetchDescriptor<SharedCareSession>()).first)
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(result.walkLogIDs.count == 2)
        #expect(session.actionKind == .walk)
        #expect(Set(walkLogs.map(\.sharedSessionId)) == Set([session.id.uuidString]))
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.walk.rawValue } == 2)
        #expect(ledgers.count { $0.coconutDelta > 0 } == 1)
        #expect(walletEntries.contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.contains { $0.ownerId == first.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.contains { $0.ownerId == second.id.uuidString && $0.delta > 0 })
        #expect(budgetEvents.count { $0.actionKey == "walk" && $0.scopeRaw == EconomyBudgetUsageScope.household.rawValue } == 1)
        #expect(budgetEvents.count { $0.actionKey == "walk" && $0.scopeRaw == EconomyBudgetUsageScope.member.rawValue } == 1)
        #expect(budgetEvents.count { $0.actionKey == "walk" && $0.scopeRaw == EconomyBudgetUsageScope.careObject.rawValue } == 2)
    }

    @Test func familyTwoPetAndHumanExpensesKeepExpenseFactsLedgerAndRewardDiscipline() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])
        let questManager = makeQuestManager()

        _ = try ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 42,
            date: Date(timeIntervalSince1970: 2100),
            category: .medical,
            note: "clinic",
            context: context,
            executorId: human.id.uuidString,
            questManager: questManager
        )
        UserDefaults.standard.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        _ = try ExpenseCommandService.recordHumanExpense(
            human: human,
            amount: 12,
            date: Date(timeIntervalSince1970: 2200),
            note: "medicine",
            context: context,
            category: .medical,
            questManager: questManager
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let budgetEvents = try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())

        #expect(expenses.count == 2)
        #expect(expenses.contains { $0.pet?.id == pet.id && $0.amount == 42 })
        #expect(expenses.contains { $0.pet == nil && $0.executorId == human.id.uuidString && $0.amount == 12 })
        #expect(ledgers.count { $0.eventKind == CareLedgerEventKind.expense.rawValue } == 2)
        #expect(ledgers.allSatisfy { $0.legacyModelName == "PetExpenseLog" })
        #expect(walletEntries.contains { $0.ownerId == human.id.uuidString && $0.delta > 0 })
        #expect(budgetEvents.count { $0.actionKey == "expense" && $0.scopeRaw == EconomyBudgetUsageScope.household.rawValue } == 2)
        #expect(budgetEvents.count { $0.actionKey == "expense" && $0.scopeRaw == EconomyBudgetUsageScope.member.rawValue } == 2)
        #expect(budgetEvents.count { $0.actionKey == "expense" && $0.scopeRaw == EconomyBudgetUsageScope.careObject.rawValue } == 1)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
    }

    @Test func familyTwoMomentKeepsPhotoFactLedgerAndRewardOutsideCareFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])

        let result = MomentCommandService.recordMoment(
            pet: pet,
            note: "sunny nap",
            photoData: [Data([1, 2, 3])],
            locationLatitude: 0,
            locationLongitude: 0,
            locationPlacename: "",
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2300),
            questManager: makeQuestManager()
        )

        let photo = try #require(try context.fetch(FetchDescriptor<PetPhotoLog>()).first)
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())

        #expect(result.savedLogIDs == [photo.id])
        #expect(result.coconutDelta == 0)
        #expect(ledgerEvents.isEmpty)
        #expect(walletEntries.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
    }

    @Test func deceasedPetExpenseNoopsWithoutFactLedgerOrReward() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])

        let result = try ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 18,
            date: Date(timeIntervalSince1970: 2400),
            category: .medical,
            note: "memorial archive",
            context: context,
            executorId: human.id.uuidString,
            questManager: makeQuestManager()
        )

        #expect(result.coconutDelta == 0)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func deceasedPetMemorialMomentWritesPhotoOnly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(human)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [pet])

        let result = MomentCommandService.recordMoment(
            pet: pet,
            note: "remembering the sunny window",
            photoData: [Data([1, 2, 3])],
            locationLatitude: 0,
            locationLongitude: 0,
            locationPlacename: "",
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2500),
            questManager: makeQuestManager()
        )

        let photos = try context.fetch(FetchDescriptor<PetPhotoLog>())
        #expect(result.savedLogIDs == photos.map(\.id))
        #expect(photos.count == 1)
        #expect(result.coconutDelta == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func activeOnlyPetCommandsNoopForDeceasedPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(pet)
        try context.save()

        let document = try PetDocumentCommandService.createDocument(
            input: PetDocumentCreateCommandInput(
                title: "Passport",
                category: .passport,
                issuingAuthority: "City",
                notes: "",
                issueDate: Date(timeIntervalSince1970: 2000),
                expiryDate: nil,
                cost: 20,
                payerId: nil,
                documentNumber: "P-1",
                attachments: []
            ),
            pet: pet,
            context: context
        )
        let insurance = try InsurancePolicyCommandService.savePolicy(
            existing: nil,
            pet: pet,
            input: InsurancePolicySaveCommandInput(
                companyName: "Care",
                policyNumber: "P",
                productName: "Plan",
                annualPremium: 120,
                coverageAmount: 1000,
                startDate: Date(timeIntervalSince1970: 2000),
                renewalDate: Date(timeIntervalSince1970: 4000),
                notes: "",
                paymentFrequency: .monthly,
                paymentDayOfMonth: 1,
                showInCalendar: true,
                otherFeeAmount: 0,
                otherFeeNote: "",
                autoGeneratesPayments: true,
                executorId: nil
            ),
            context: context
        )
        let medication = PetMedicationPlanCommandService.savePlan(
            pet: pet,
            editing: nil,
            input: PetMedicationPlanCommandInput(
                name: "Pill",
                dosage: "1",
                frequency: .daily,
                doseMinutes: [480],
                startDate: Date(timeIntervalSince1970: 2000),
                endDate: nil,
                colorHex: "FF0000",
                notes: "",
                isActive: true,
                remainingAmount: 5
            ),
            context: context
        )

        #expect(!document.didChange)
        #expect(!insurance.didChange)
        #expect(medication == nil)
        #expect(try context.fetch(FetchDescriptor<PetDocument>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetInsurance>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func activeOnlyHumanCommandsNoopForDeceasedHumanButMemorialNoteWritesWithoutReminder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        human.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(human)
        try context.save()

        let weight = try WeightCommandService.recordHumanWeight(
            human: human,
            weight: 62,
            date: Date(timeIntervalSince1970: 2000),
            context: context
        )
        let workout = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 20,
            date: Date(timeIntervalSince1970: 2000),
            context: context
        )
        let metric = HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 4.2,
            date: Date(timeIntervalSince1970: 2000),
            notes: "",
            context: context
        )
        let note = try #require(HumanNoteCommandService.recordNote(
            human: human,
            note: "We miss your laugh",
            date: Date(timeIntervalSince1970: 2000),
            imageAttachments: [],
            fileAttachments: [],
            reminderDate: nil,
            appLanguage: "en",
            context: context,
            scheduleNotification: false
        ))

        #expect(!weight.didRecord)
        #expect(workout.ledgerEventID == nil)
        #expect(metric == nil)
        #expect(note.subjectID == human.id)
        #expect(note.eventID == nil)
        #expect(note.reminderID == nil)
        #expect(human.notes.contains("We miss your laugh"))
        #expect(try context.fetch(FetchDescriptor<HumanWeightLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func frozenExplicitCareExecutorWritesActiveTargetFactThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let frozenExecutor = Human(name: "Frozen")
        frozenExecutor.passedAwayDate = Date(timeIntervalSince1970: 1000)
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(activeHuman)
        context.insert(frozenExecutor)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, frozenExecutor], pets: [pet])

        let record = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 80,
            context: context,
            executorId: frozenExecutor.id.uuidString,
            date: Date(timeIntervalSince1970: 2000),
            dependencies: .live()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        #expect(record.result.disposition == .active)
        #expect(record.result.didWriteFact)
        #expect(record.log.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(record.reward.humanGot + record.reward.petGot > 0)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != frozenExecutor.id.uuidString })
        #expect(!(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())).isEmpty)
    }

    @Test func missingExplicitCareExecutorWritesFactLedgerRewardAndOasisEchoThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "cat")
        let critter = OasisElectronicPet(
            catalogId: "leafling",
            nameZh: "叶灵",
            nameEn: "Leafling",
            nameDe: "Blattling",
            emoji: "🌱",
            rarity: .common,
            xp: 0,
            bond: 0,
            isFeaturedOnOasis: true,
            sourceLevel: 1
        )
        context.insert(activeHuman)
        context.insert(pet)
        context.insert(critter)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman], pets: [pet])
        let missingExecutorID = UUID().uuidString

        let record = CareEventService.recordManualFeedFact(
            pet: pet,
            amountGrams: 80,
            context: context,
            executorId: missingExecutorID,
            date: Date(timeIntervalSince1970: 2000),
            dependencies: .live()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)

        #expect(record.result.disposition == .active)
        #expect(record.result.didWriteFact)
        #expect(record.log.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(record.reward.humanGot + record.reward.petGot > 0)
        #expect(activeHuman.coconutBalance > 0)
        #expect(critter.xp > 0)
        #expect(critter.bond > 0)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != missingExecutorID })
        #expect(!(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())).isEmpty)
        #expect(!(try context.fetch(FetchDescriptor<OasisCritterActionLog>())).isEmpty)
    }

    @Test func sharedCareWritesForMissingExplicitExecutorThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let first = Pet(name: "Momo", species: "cat")
        let second = Pet(name: "Nana", species: "cat")
        context.insert(activeHuman)
        context.insert(first)
        context.insert(second)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman], pets: [first, second])
        let missingExecutorID = UUID().uuidString

        let result = CareEventService.recordSharedWateringFact(
            sourcePet: first,
            targets: [first, second],
            totalMl: 120,
            context: context,
            executorId: missingExecutorID,
            date: Date(timeIntervalSince1970: 2000)
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(result.disposition == .active)
        #expect(result.didWriteFact)
        #expect(result.coconutDelta > 0)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).count == 1)
        #expect(careLogs.count == 2)
        #expect(careLogs.allSatisfy { $0.executorId == activeHuman.id.uuidString })
        #expect(!ledgers.isEmpty)
        #expect(ledgers.allSatisfy { $0.actorId != missingExecutorID })
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != missingExecutorID })
        #expect(!(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())).isEmpty)
    }

    @Test func medicationDoseRejectsMissingConfirmedExecutorWithoutFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "cat")
        let medication = PetMedication(
            name: "Antibiotic",
            dosage: "1 pill",
            frequency: .daily,
            remainingAmount: 5,
            pet: pet
        )
        context.insert(activeHuman)
        context.insert(pet)
        context.insert(medication)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman], pets: [pet])
        let medicationReminders = MedicationReminderManagerSpy()
        let missingExecutorID = UUID().uuidString

        let result = PetMedicationDoseLogging.recordDoseResult(
            medication: medication,
            pet: pet,
            modelContext: context,
            awardCoconut: true,
            economy: StaticCareEventEconomyAwarder(questManager: makeQuestManager()),
            executorId: missingExecutorID,
            medicationReminders: medicationReminders
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(!result.didRecord)
        #expect(result.coconutDelta == 0)
        #expect(!result.allowsDerivedEffects)
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(walletEntries.isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(medication.remainingAmount == 5)
        #expect(medicationReminders.recordedMedicationIDs.isEmpty)
    }

    @Test func calendarCompletionForMissingExplicitExecutorWritesFactAndCompletesThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let pet = Pet(name: "Momo", species: "cat")
        let occurrenceDate = Date(timeIntervalSince1970: 2000)
        let event = Event(
            title: "Feed Momo 80g",
            startDate: occurrenceDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(activeHuman)
        context.insert(pet)
        context.insert(event)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman], pets: [pet])
        let missingExecutorID = UUID().uuidString

        let result = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: [pet],
            context: context,
            executorId: missingExecutorID,
            now: Date(timeIntervalSince1970: 4000)
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let log = try #require(try context.fetch(FetchDescriptor<PetCareLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)

        #expect(result.isCompleted)
        #expect(result.didChange)
        #expect(event.isOccurrenceMarkedComplete(on: occurrenceDate))
        #expect(log.executorId == activeHuman.id.uuidString)
        #expect(ledger.actorId == activeHuman.id.uuidString)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != missingExecutorID })
        #expect(!(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())).isEmpty)
    }

    @Test func sharedCareRejectsTheWholeSelectionWhenATargetIsDeceased() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let sourcePet = Pet(name: "Momo", species: "cat")
        let deceasedPet = Pet(name: "Nana", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(human)
        context.insert(sourcePet)
        context.insert(deceasedPet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [sourcePet, deceasedPet])

        _ = CareEventService.recordSharedManualFeed(
            sourcePet: sourcePet,
            targets: [sourcePet, deceasedPet],
            totalGrams: 120,
            foodKind: .dry,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2000)
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let sharedSessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(sharedSessions.isEmpty)
        #expect(careLogs.isEmpty)
        #expect(walletEntries.isEmpty)
        #expect(ledgerEvents.isEmpty)
    }

    @Test func deceasedPetCareFactIsNoopAtFactBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        context.insert(human)
        context.insert(deceasedPet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [deceasedPet])

        _ = CareEventService.recordManualFeedFact(
            pet: deceasedPet,
            amountGrams: 80,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2000),
            dependencies: .live()
        )

        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func deceasedPetHistoricalCareDoesNotWriteFactOrDerivedEffects() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 3000)
        context.insert(human)
        context.insert(deceasedPet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [deceasedPet])

        _ = CareEventService.recordManualFeedFact(
            pet: deceasedPet,
            amountGrams: 80,
            context: context,
            executorId: human.id.uuidString,
            date: Date(timeIntervalSince1970: 2000),
            dependencies: .live()
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(careLogs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func weightAndHealthWriteFactsForDeceasedExecutorThroughFallbackOwner() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let executor = Human(name: "Former caretaker")
        executor.passedAwayDate = Date(timeIntervalSince1970: 1000)
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(activeHuman)
        context.insert(executor)
        context.insert(pet)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: activeHuman.id.uuidString, humans: [activeHuman, executor], pets: [pet])

        _ = try WeightCommandService.recordPetWeight(
            pet: pet,
            weight: 4.2,
            date: Date(timeIntervalSince1970: 2000),
            context: context,
            executorId: executor.id.uuidString,
            ledgerSource: .detail
        )
        let health = PetHealthCommandService.recordHealth(
            pet: pet,
            input: PetHealthRecordCommandInput(
                type: .vaccine,
                date: Date(timeIntervalSince1970: 2100),
                name: "Rabies",
                note: "",
                vetName: "",
                cost: 0,
                expirationDate: Date(timeIntervalSince1970: 2200),
                nextCheckupDate: nil,
                executorId: executor.id.uuidString,
                source: .detail,
                includesNameInNote: true,
                expirationReminderLeadDays: 1
            ),
            context: context,
            questManager: makeQuestManager()
        )

        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(health != nil)
        #expect(try context.fetch(FetchDescriptor<PetWeightLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetHealthLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Event>()).count == 1)
        #expect(!(try context.fetch(FetchDescriptor<CareLedgerEvent>())).isEmpty)
        #expect(walletEntries.contains { $0.ownerId == activeHuman.id.uuidString && $0.delta > 0 })
        #expect(walletEntries.allSatisfy { $0.ownerId != executor.id.uuidString })
        #expect(!(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>())).isEmpty)
    }

    @Test func calendarCompletionForDeceasedPetIsNoop() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 1000)
        let occurrenceDate = Date(timeIntervalSince1970: 2000)
        let event = Event(
            title: "Feed Momo 80g",
            startDate: occurrenceDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: deceasedPet.id.uuidString
        )
        context.insert(human)
        context.insert(deceasedPet)
        context.insert(event)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [deceasedPet])

        let result = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: [deceasedPet],
            context: context,
            executorId: human.id.uuidString,
            now: Date(timeIntervalSince1970: 4000)
        )

        #expect(result.isCompleted == false)
        #expect(event.isOccurrenceMarkedComplete(on: occurrenceDate) == false)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func calendarHistoricalCompletionForDeceasedPetDoesNotWriteFactOrComplete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 3000)
        let occurrenceDate = Date(timeIntervalSince1970: 2000)
        let operationDate = Date(timeIntervalSince1970: 4000)
        let event = Event(
            title: "Feed Momo 80g",
            startDate: occurrenceDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: deceasedPet.id.uuidString
        )
        context.insert(human)
        context.insert(deceasedPet)
        context.insert(event)
        try context.save()

        let state = EconomyDefaultsState.capture()
        defer { state.restore() }
        resetEconomy(activeHumanID: human.id.uuidString, humans: [human], pets: [deceasedPet])

        let first = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: [deceasedPet],
            context: context,
            executorId: human.id.uuidString,
            now: operationDate
        )
        let second = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: [deceasedPet],
            context: context,
            executorId: human.id.uuidString,
            now: operationDate
        )

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(first.isCompleted == false)
        #expect(first.didChange == false)
        #expect(second.isCompleted == false)
        #expect(second.didChange == false)
        #expect(event.isOccurrenceMarkedComplete(on: occurrenceDate) == false)
        #expect(careLogs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func calendarReopenForDeceasedPetLeavesLegacyFactOnlyHistoryReadOnly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let deceasedPet = Pet(name: "Momo", species: "cat")
        deceasedPet.passedAwayDate = Date(timeIntervalSince1970: 3000)
        let occurrenceDate = Date(timeIntervalSince1970: 2000)
        let event = Event(
            title: "Feed Momo 80g",
            startDate: occurrenceDate,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: deceasedPet.id.uuidString
        )
        let legacyFactOnlyLog = PetCareLog(
            date: occurrenceDate,
            type: .feeding,
            amountGrams: 80,
            note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString):calendar:\(Event.occurrenceStorageKey(for: occurrenceDate))",
            pet: deceasedPet,
            executorId: human.id.uuidString
        )
        event.setOccurrenceMarkedComplete(true, on: occurrenceDate)
        event.isCompleted = true
        context.insert(human)
        context.insert(deceasedPet)
        context.insert(event)
        context.insert(legacyFactOnlyLog)
        try context.save()

        let result = try CalendarEventCommandService.toggleCompletion(
            event: event,
            occurrenceDate: occurrenceDate,
            pets: [deceasedPet],
            context: context,
            executorId: human.id.uuidString,
            now: Date(timeIntervalSince1970: 4000)
        )

        #expect(result.isCompleted)
        #expect(result.didChange == false)
        #expect(event.isOccurrenceMarkedComplete(on: occurrenceDate))
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV91.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeQuestManager() -> QuestManager {
        makeQuestManager(wallet: SwiftDataCoconutWalletManager())
    }

    private func makeQuestManager(wallet: CoconutWalletManaging) -> QuestManager {
        let questManager = QuestManager(wallet: wallet, revisions: SharedDomainRevisionPublisher())
        questManager.coconutCount = 0
        questManager.coconutLogs = []
        questManager.lastEconomyRewardResult = nil
        return questManager
    }

    private func resetEconomy(activeHumanID: String, humans: [Human], pets: [Pet]) {
        let defaults = UserDefaults.standard
        defaults.set(activeHumanID, forKey: "currentActiveHumanId")
        defaults.removeObject(forKey: QuestManager.Keys.cooldownLogs)
        defaults.removeObject(forKey: "shop_boostDoubleActive")
        EconomyDailyBudgetStore.resetAll()
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey()
        let careObjectKeys = pets.map { "pet.\($0.id.uuidString)" }
        for human in humans {
            EconomyDailyBudgetStore.reset(
                householdKey: householdKey,
                memberKey: human.id.uuidString,
                careObjectKeys: careObjectKeys
            )
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
        EconomyDailyBudgetStore.resetAll()
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

private final class MedicationReminderManagerSpy: MedicationReminderManaging {
    private(set) var recordedMedicationIDs: [UUID] = []

    func dosesTakenToday(for _: UUID) -> Int { 0 }
    func recordDose(for medicationId: UUID) { recordedMedicationIDs.append(medicationId) }
    func undoDose(for _: UUID) {}
    func scheduleMedicationReminders(for _: Pet, context _: ModelContext?) {}
    func scheduleHumanMedicationReminders(for _: Human, meds _: [HumanMedication], context _: ModelContext?) {}
}

private final class FakeWalkLocationManager: WalkLocationManaging {
    var currentLocation: CLLocation?
    var collectedLocations: [CLLocation] = []
    var totalDistance: Double = 0

    func startWalkSession() {}
    func stopWalkSession() {}
    func pauseWalkSession() {}
    func resumeWalkSession() {}
    func stopAllLocationActivity() {}
    func promoteActiveWalkToBackgroundDelivery() {}
    func returnActiveWalkToForegroundDelivery() {}
    func enforceNoLocationUnlessRunningWalk(_: Bool, reason _: String) {}
    func routeLocationsForPersistence(maxCount _: Int) -> [CLLocation] { collectedLocations }
}

@MainActor
private final class WalkFactOrderAssertingWallet: CoconutWalletManaging {
    private let base = SwiftDataCoconutWalletManager()
    private(set) var factCountSeenDuringReward = 0

    func apply(
        deltas: [CoconutWalletDelta],
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        updatesProjection: Bool,
        projectionManager: CoconutProjectionManaging?
    ) throws -> [CoconutLedgerEntry] {
        factCountSeenDuringReward = try context.fetch(FetchDescriptor<PetWalkLog>()).count
        return try base.apply(
            deltas: deltas,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            updatesProjection: updatesProjection,
            projectionManager: projectionManager
        )
    }

    func applyActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool,
        projectionManager: CoconutProjectionManaging?
    ) throws -> [CoconutLedgerEntry] {
        try base.applyActorDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            actorId: actorId,
            actorName: actorName,
            entryKind: entryKind,
            source: source,
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            projectionManager: projectionManager
        )
    }

    func totalBalance(context: ModelContext) -> Int { base.totalBalance(context: context) }
    func balance(accountKey: String, context: ModelContext, fallback: Int) -> Int { base.balance(accountKey: accountKey, context: context, fallback: fallback) }
    func balance(for human: Human, context: ModelContext) -> Int { base.balance(for: human, context: context) }
    func balance(for pet: Pet, context: ModelContext) -> Int { base.balance(for: pet, context: context) }
    func legacySystemBalance(context: ModelContext, fallback: Int) -> Int { base.legacySystemBalance(context: context, fallback: fallback) }
    func setDeveloperOverrideBalance(amount: Int, for human: Human?, displayName: String, context: ModelContext) {
        base.setDeveloperOverrideBalance(amount: amount, for: human, displayName: displayName, context: context)
    }
    func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging?) {
        base.refreshQuestProjection(context: context, manager: manager)
    }
    func bootstrapIfNeeded(context: ModelContext, projectionManager: CoconutProjectionManaging?) throws {
        try base.bootstrapIfNeeded(context: context, projectionManager: projectionManager)
    }
}
