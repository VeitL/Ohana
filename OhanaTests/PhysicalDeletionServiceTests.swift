import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct PhysicalDeletionServiceTests {
    final class FakeNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var cancelledIds: [String] = []

        func schedule(reminder _: Reminder) {}

        func schedule(
            reminder _: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func schedule(
            reminder _: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}
        func cancel(notificationId: String) { cancelledIds.append(notificationId) }
        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }

    @Test func physicalDeletionCoverageMatchesCloudSyncRegistryOwnershipManifest() {
        #expect(
            PhysicalDeletionService.localPhysicalDeletionCascadeCoverage(parent: .pet) ==
                CloudSyncEntityRegistry.physicalDeletionOwnedEntityNames(parent: .pet)
        )
        #expect(
            PhysicalDeletionService.localPhysicalDeletionCascadeCoverage(parent: .human) ==
                CloudSyncEntityRegistry.physicalDeletionOwnedEntityNames(parent: .human)
        )
        #expect(
            PhysicalDeletionService.localPhysicalDeletionCascadeCoverage(parent: .plant) ==
                CloudSyncEntityRegistry.physicalDeletionOwnedEntityNames(parent: .plant)
        )
    }

    @Test func deleteDocumentPhysicallyDeletesAttachmentsAndWritesTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo")
        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        let attachment = PetDocumentAttachment(data: Data([1, 2, 3]), filename: "scan.jpg", isImage: true)
        document.attachments = [attachment]

        context.insert(pet)
        context.insert(document)
        context.insert(attachment)
        try context.save()

        PhysicalDeletionService.deleteDocument(document, pet: pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PetDocument>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetDocumentAttachment>()).isEmpty)
        #expect(deletionTombstone(PetDocument.self, id: document.id, context: context) != nil)
        #expect(deletionTombstone(PetDocumentAttachment.self, id: attachment.id, context: context) != nil)
    }

    @Test func deletePetPhysicallyDeletesCareFactsAndWritesTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo")
        let careLog = PetCareLog(type: .feeding, pet: pet)
        let walkLog = PetWalkLog(pet: pet)

        context.insert(pet)
        context.insert(careLog)
        context.insert(walkLog)
        try context.save()

        PhysicalDeletionService.deletePet(pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).isEmpty)
        #expect(deletionTombstone(Pet.self, id: pet.id, context: context) != nil)
        #expect(deletionTombstone(PetCareLog.self, id: careLog.id, context: context) != nil)
        #expect(deletionTombstone(PetWalkLog.self, id: walkLog.id, context: context) != nil)
    }

    @Test func deletePlantPhysicallyDeletesCareFactsEventsAndNotifications() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let scheduler = FakeNotificationScheduler()
        let plant = Plant(name: "Fern")
        let plantID = plant.id
        let log = PlantCareLog(
            date: Date(timeIntervalSinceReferenceDate: 10),
            careType: .watering
        )
        log.plant = plant
        let event = Event(
            title: "Water Fern",
            startDate: Date(timeIntervalSinceReferenceDate: 20),
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plantID.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSinceReferenceDate: 20))
        reminder.notificationId = "plant-water-reminder"
        event.reminders = [reminder]
        let unrelatedEvent = Event(
            title: "Other Plant",
            startDate: Date(timeIntervalSinceReferenceDate: 20),
            eventType: EventType.watering.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: UUID().uuidString
        )
        let ledger = CareLedgerEvent(
            occurredAt: log.date,
            subjectKind: .plant,
            subjectId: plantID.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            sourceEventId: event.id.uuidString,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString
        )
        let rewardLedger = CareLedgerEvent(
            occurredAt: log.date,
            subjectKind: .plant,
            subjectId: plantID.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            sourceEventId: event.id.uuidString,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            coconutDelta: 2,
            rewardLogId: "plant-reward-ledger"
        )
        let plantTask = FamilyCollaborationTask(
            title: "Fertilize Fern",
            kind: .careReminder,
            subjectKind: .plant,
            subjectId: plantID.uuidString,
            createdById: UUID().uuidString,
            createdByName: "Creator"
        )

        context.insert(plant)
        context.insert(log)
        context.insert(event)
        context.insert(reminder)
        context.insert(unrelatedEvent)
        context.insert(ledger)
        context.insert(rewardLedger)
        context.insert(plantTask)
        try context.save()

        PhysicalDeletionService.deletePlant(plant, context: context, notifications: scheduler)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Plant>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PlantCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
        let retainedLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(retainedLedgers.map(\.id) == [rewardLedger.id])
        #expect(retainedLedgers.first?.subjectKind == CareLedgerSubjectKind.unknown.rawValue)
        #expect(retainedLedgers.first?.subjectId == nil)
        #expect(retainedLedgers.first?.legacyModelName == nil)
        #expect(retainedLedgers.first?.legacyModelId == nil)
        #expect(retainedLedgers.first?.metadataJSON.contains("\"deletedOwnerRetention\":true") == true)
        #expect(retainedLedgers.first?.metadataJSON.contains("\"deletedOwnerKind\":\"plant\"") == true)
        #expect(try context.fetch(FetchDescriptor<Event>()).map(\.id) == [unrelatedEvent.id])
        #expect(scheduler.cancelledIds == ["plant-water-reminder"])
        #expect(deletionTombstone(Plant.self, id: plantID, context: context) != nil)
        #expect(deletionTombstone(PlantCareLog.self, id: log.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: reminder.id, context: context) != nil)
        #expect(deletionTombstone(FamilyCollaborationTask.self, id: plantTask.id, context: context) != nil)
        #expect(deletionTombstone(CareLedgerEvent.self, id: ledger.id, context: context) != nil)
        #expect(deletionTombstone(CareLedgerEvent.self, id: rewardLedger.id, context: context) == nil)
    }

    @Test func deletePlantRetainsHumanCoconutRewardAndReconcilesWalletDrift() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let plant = Plant(name: "Mint")
        human.coconutBalance = 99
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            displayName: human.name,
            balance: 99
        )
        let plantCareReward = CoconutLedgerEntry(
            transactionKey: "delete-plant-human-reward",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            delta: 8,
            balanceBefore: 0,
            balanceAfter: 8,
            entryKind: .reward,
            source: .careEvent,
            title: "Plant care reward",
            emoji: "coconut",
            actorId: human.id.uuidString,
            actorName: human.name,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            sourceModelName: String(describing: PlantCareLog.self),
            sourceModelId: UUID().uuidString
        )
        context.insert(human)
        context.insert(plant)
        context.insert(account)
        context.insert(plantCareReward)
        try context.save()

        PhysicalDeletionService.deletePlant(plant, context: context)
        try context.save()

        let remainingAccount = try #require(try context.fetch(FetchDescriptor<CoconutAccount>()).first {
            $0.accountKey == CoconutAccountKey.human(human.id)
        })
        #expect(remainingAccount.balance == 8)
        #expect(human.coconutBalance == 8)
        #expect(CoconutWalletService.totalBalance(context: context) == 8)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).map(\.id) == [plantCareReward.id])
        #expect(deletionTombstone(CoconutLedgerEntry.self, id: plantCareReward.id, context: context) == nil)
    }

    @Test func deletePetRetiresWalletAccountKeepsLedgerAndScrubsSharedSessionReferences() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deletedPet = Pet(name: "Milo", species: "猫")
        let survivor = Pet(name: "Luna", species: "猫")
        let session = SharedCareSession(
            date: Date(timeIntervalSinceReferenceDate: 10),
            actionKind: .feeding,
            sourcePetId: deletedPet.id.uuidString,
            targetPetIds: [deletedPet.id.uuidString, survivor.id.uuidString],
            species: "猫",
            totalAmountGrams: 120,
            stockOwnerPetId: deletedPet.id.uuidString
        )
        let undoReceipt = SharedCareUndoReceipt(
            sharedSessionId: session.id,
            sourcePetId: deletedPet.id,
            targetPetIds: [deletedPet.id, survivor.id],
            actionKind: .litterScoop,
            occurredAt: session.date,
            undoDeadline: session.date.addingTimeInterval(6)
        )
        let deletedLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 60,
            sharedSessionId: session.id.uuidString,
            pet: deletedPet
        )
        let survivorLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 60,
            sharedSessionId: session.id.uuidString,
            pet: survivor
        )
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.pet(deletedPet.id),
            ownerKind: .pet,
            ownerId: deletedPet.id.uuidString,
            displayName: deletedPet.name,
            balance: 12
        )
        let walletEntry = CoconutLedgerEntry(
            transactionKey: "delete-pet-wallet-entry",
            accountKey: CoconutAccountKey.pet(deletedPet.id),
            ownerKind: .pet,
            ownerId: deletedPet.id.uuidString,
            ownerName: deletedPet.name,
            delta: 12,
            balanceBefore: 0,
            balanceAfter: 12,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "coconut"
        )
        let careLedger = CareLedgerEvent(
            occurredAt: session.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: deletedPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: deletedLog.id.uuidString
        )
        let rewardCareLedger = CareLedgerEvent(
            occurredAt: session.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: deletedPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: deletedLog.id.uuidString,
            coconutDelta: 3,
            rewardLogId: "delete-pet-reward-ledger"
        )
        context.insert(deletedPet)
        context.insert(survivor)
        context.insert(session)
        context.insert(undoReceipt)
        context.insert(deletedLog)
        context.insert(survivorLog)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        context.insert(rewardCareLedger)
        try context.save()

        PhysicalDeletionService.deletePet(deletedPet, context: context)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let undoReceipts = try context.fetch(FetchDescriptor<SharedCareUndoReceipt>())

        let retiredAccount = try #require(accounts.first { $0.ownerId == deletedPet.id.uuidString })
        #expect(retiredAccount.balance == 0)
        #expect(CoconutWalletAccountLifecycleMetadata.isDeletedOwner(retiredAccount))
        #expect(walletEntries.map(\.id) == [walletEntry.id])
        #expect(careLedgers.map(\.id) == [rewardCareLedger.id])
        #expect(careLedgers.first?.subjectKind == CareLedgerSubjectKind.unknown.rawValue)
        #expect(careLedgers.first?.subjectId == nil)
        #expect(careLedgers.first?.legacyModelName == nil)
        #expect(careLedgers.first?.legacyModelId == nil)
        #expect(careLedgers.first?.metadataJSON.contains("\"deletedOwnerRetention\":true") == true)
        #expect(careLedgers.first?.metadataJSON.contains("\"deletedOwnerKind\":\"pet\"") == true)
        #expect(careLogs.allSatisfy { $0.pet?.id != deletedPet.id })
        #expect(careLogs.contains { $0.pet?.id == survivor.id })
        #expect(sessions.allSatisfy { session in
            !session.targetPetIds.contains(deletedPet.id.uuidString)
                && session.sourcePetId != deletedPet.id.uuidString
                && session.stockOwnerPetId != deletedPet.id.uuidString
        })
        #expect(sessions.first?.targetPetIds == [survivor.id.uuidString])
        #expect(sessions.first?.sourcePetId.isEmpty == true)
        #expect(sessions.first?.stockOwnerPetId.isEmpty == true)
        #expect(undoReceipts.isEmpty)
        #expect(sessions.first?.totalAmountGrams == survivorLog.amountGrams)
        #expect(CoconutWalletService.totalBalance(context: context) == 0)
        #expect(deletionTombstone(CoconutLedgerEntry.self, id: walletEntry.id, context: context) == nil)
        #expect(deletionTombstone(CareLedgerEvent.self, id: careLedger.id, context: context) != nil)
        #expect(deletionTombstone(CareLedgerEvent.self, id: rewardCareLedger.id, context: context) == nil)
    }

    @Test func deletePetRetainsPetScopedHumanRewardsWithoutRollback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let deletedPet = Pet(name: "Milo", species: "猫")
        human.coconutBalance = 10
        let humanAccount = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            displayName: human.name,
            balance: 10
        )
        let petCareReward = CoconutLedgerEntry(
            transactionKey: "delete-pet-human-reward",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            delta: 10,
            balanceBefore: 0,
            balanceAfter: 10,
            entryKind: .reward,
            source: .careEvent,
            title: "Care reward",
            emoji: "coconut",
            actorId: human.id.uuidString,
            actorName: human.name,
            subjectKind: .pet,
            subjectId: deletedPet.id.uuidString,
            sourceModelName: "PetCareLog",
            sourceModelId: UUID().uuidString
        )
        context.insert(human)
        context.insert(deletedPet)
        context.insert(humanAccount)
        context.insert(petCareReward)
        try context.save()

        PhysicalDeletionService.deletePet(deletedPet, context: context)
        try context.save()

        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let remainingAccount = try #require(accounts.first { $0.accountKey == CoconutAccountKey.human(human.id) })
        #expect(remainingAccount.balance == 10)
        #expect(human.coconutBalance == 10)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).map(\.id) == [petCareReward.id])
        #expect(deletionTombstone(CoconutLedgerEntry.self, id: petCareReward.id, context: context) == nil)
    }

    @Test func deletePetCascadesFirstReleaseRegisteredOwnedEntities() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "狗")
        let survivor = Pet(name: "Luna", species: "猫")
        let event = Event(
            title: "Momo vaccine",
            eventType: EventType.vaccine.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event)
        event.reminders = [reminder]
        let relationship = PetRelationship(fromPetId: pet.id, toPetId: survivor.id, type: .sibling)
        let task = FamilyCollaborationTask(
            title: "Care for Momo",
            kind: .careReminder,
            relatedPetId: pet.id.uuidString,
            createdById: human.id.uuidString,
            createdByName: human.name
        )
        let session = SharedCareSession(
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString],
            species: pet.species,
            stockOwnerPetId: pet.id.uuidString
        )
        let careLog = PetCareLog(type: .feeding, sharedSessionId: session.id.uuidString, pet: pet, executorId: human.id.uuidString)
        let pottyLog = PetPottyLog(pet: pet, executorId: human.id.uuidString)
        let hygieneLog = PetHygieneLog(pet: pet, executorId: human.id.uuidString)
        let healthLog = PetHealthLog(type: .vaccine, pet: pet, executorId: human.id.uuidString)
        let walkLog = PetWalkLog(pet: pet, executorId: human.id.uuidString)
        let expenseLog = PetExpenseLog(amount: 12, pet: pet, executorId: human.id.uuidString)
        let weightLog = PetWeightLog(weight: 6.2, pet: pet, executorId: human.id.uuidString)
        let foodRecord = PetFoodRecord(brand: "Test Food", totalGrams: 1000, pet: pet, executorId: human.id.uuidString)
        let medication = PetMedication(name: "Drops", pet: pet)
        let photo = PetPhotoLog(imageData: Data([1, 2, 3]), pet: pet)
        let milestone = PetMilestone(title: "First walk", pet: pet)
        let document = PetDocument(title: "Passport", pet: pet)
        let attachment = PetDocumentAttachment(data: Data([4, 5]), filename: "scan.jpg", isImage: true)
        document.attachments = [attachment]
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        let claim = InsuranceClaim(totalExpense: 30, claimedAmount: 20, insurance: insurance)
        insurance.claims = [claim]
        let symptom = SymptomLog(category: .digestive, symptomName: "Cough", severity: .mild, pet: pet)
        let heat = HeatCycleLog(pet: pet)
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            displayName: pet.name,
            balance: 8
        )
        let walletEntry = CoconutLedgerEntry(
            transactionKey: "pet-delete-owned-wallet",
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            ownerName: pet.name,
            delta: 8,
            balanceBefore: 0,
            balanceAfter: 8,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "coconut",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            sourceModelName: String(describing: PetCareLog.self),
            sourceModelId: careLog.id.uuidString
        )
        let careLedger = CareLedgerEvent(
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: careLog.id.uuidString
        )
        let budgetUsage = EconomyBudgetUsageEvent(
            dayKey: "2026-06-14",
            householdKey: "household",
            memberKey: human.id.uuidString,
            careObjectKey: pet.id.uuidString,
            scope: .careObject,
            scopeKey: pet.id.uuidString,
            growthXPUsed: 1,
            coconutUsed: 2,
            actionKey: "feeding",
            source: "test"
        )
        context.insert(human)
        context.insert(pet)
        context.insert(survivor)
        context.insert(event)
        context.insert(reminder)
        context.insert(relationship)
        context.insert(task)
        context.insert(session)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(healthLog)
        context.insert(walkLog)
        context.insert(expenseLog)
        context.insert(weightLog)
        context.insert(foodRecord)
        context.insert(medication)
        context.insert(photo)
        context.insert(milestone)
        context.insert(document)
        context.insert(attachment)
        context.insert(insurance)
        context.insert(claim)
        context.insert(symptom)
        context.insert(heat)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        context.insert(budgetUsage)
        try context.save()

        PhysicalDeletionService.deletePet(pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Pet>()).map(\.id) == [survivor.id])
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetRelationship>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetPottyLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHygieneLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetHealthLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetWeightLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetFoodRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetPhotoLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetMilestone>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetDocument>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetDocumentAttachment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetInsurance>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InsuranceClaim>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SymptomLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HeatCycleLog>()).isEmpty)
        let retiredAccount = try #require(try context.fetch(FetchDescriptor<CoconutAccount>()).first { $0.ownerId == pet.id.uuidString })
        #expect(retiredAccount.balance == 0)
        #expect(CoconutWalletAccountLifecycleMetadata.isDeletedOwner(retiredAccount))
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).map(\.id) == [walletEntry.id])
        #expect(CoconutWalletService.totalBalance(context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(deletionTombstone(Pet.self, id: pet.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: reminder.id, context: context) != nil)
        #expect(deletionTombstone(PetRelationship.self, id: relationship.id, context: context) != nil)
        #expect(deletionTombstone(FamilyCollaborationTask.self, id: task.id, context: context) != nil)
        #expect(deletionTombstone(EconomyBudgetUsageEvent.self, id: budgetUsage.id, context: context) != nil)
    }

    @Test func deletePetUsesUnifiedResolverForIndirectScheduleEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let survivor = Pet(name: "Luna", species: "cat")
        let medication = PetMedication(name: "Drops", pet: pet)
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        let stockEvent = Event(
            title: "Food stock",
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        let medicationEvent = Event(
            title: "Medication",
            eventType: EventType.petMedication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
        let insuranceEvent = Event(
            title: "Insurance",
            eventType: EventType.insurancePremium.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.petInsurance,
            relatedEntityId: insurance.id.uuidString
        )
        let survivorEvent = Event(
            title: "Survivor",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: survivor.id.uuidString
        )
        let stockReminder = Reminder(event: stockEvent)
        let medicationReminder = Reminder(event: medicationEvent)
        let insuranceReminder = Reminder(event: insuranceEvent)
        let survivorReminder = Reminder(event: survivorEvent)
        stockEvent.reminders = [stockReminder]
        medicationEvent.reminders = [medicationReminder]
        insuranceEvent.reminders = [insuranceReminder]
        survivorEvent.reminders = [survivorReminder]

        context.insert(pet)
        context.insert(survivor)
        context.insert(medication)
        context.insert(insurance)
        context.insert(stockEvent)
        context.insert(medicationEvent)
        context.insert(insuranceEvent)
        context.insert(survivorEvent)
        context.insert(stockReminder)
        context.insert(medicationReminder)
        context.insert(insuranceReminder)
        context.insert(survivorReminder)
        try context.save()

        PhysicalDeletionService.deletePet(pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Event>()).map(\.id) == [survivorEvent.id])
        #expect(try context.fetch(FetchDescriptor<Reminder>()).map(\.id) == [survivorReminder.id])
        #expect(deletionTombstone(Event.self, id: stockEvent.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: medicationEvent.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: insuranceEvent.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: stockReminder.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: medicationReminder.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: insuranceReminder.id, context: context) != nil)
    }

    @Test func deleteHumanCascadesFirstReleaseRegisteredOwnedEntities() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let survivor = Human(name: "Alex")
        let pet = Pet(name: "Momo")
        let humanId = human.id.uuidString
        let event = Event(
            title: "Guan birthday",
            eventType: EventType.birthday.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: humanId
        )
        let reminder = Reminder(event: event)
        event.reminders = [reminder]
        let medication = HumanMedication(humanId: humanId, name: "Vitamin")
        let dose = HumanMedicationLog(humanId: humanId, medicationId: medication.id.uuidString, scheduledTime: Date())
        let report = HumanHealthReport(humanId: humanId)
        let wishlist = WishlistItem(title: "Treat", creatorId: humanId)
        let ownedItem = GachaOwnedItem(ownerHumanId: humanId, seriesId: GachaSeriesCatalog.defaultSeriesId, itemId: "plush_coconut_sleepy")
        let drawLog = GachaDrawLog(ownerHumanId: humanId, ownerName: human.name, seriesId: GachaSeriesCatalog.defaultSeriesId, itemId: "plush_coconut_sleepy")
        let purchase = ShopPurchaseRecord(transactionKey: "shop:owned:\(humanId)", itemId: "fx_lime_glow", buyerHumanId: humanId)
        let privateExpense = PetExpenseLog(amount: 18, pet: nil, executorId: humanId)
        let retainedPetExpense = PetExpenseLog(
            amount: 24,
            pet: pet,
            executorId: survivor.id.uuidString,
            recordedByHumanId: humanId
        )
        let retainedHumanExpense = PetExpenseLog(
            amount: 9,
            pet: nil,
            executorId: survivor.id.uuidString,
            recordedByHumanId: humanId
        )
        let retainedNoteRecord = HumanNoteRecord(
            humanId: survivor.id,
            sequence: 0,
            date: Date(),
            rawEntry: "[2026-07-15] survivor note",
            recordedByHumanId: humanId
        )
        let retainedSymptom = SymptomLog(
            category: .skin,
            symptomName: "itch",
            severity: .mild,
            recordedByHumanId: humanId,
            pet: pet
        )
        let retainedHeatCycle = HeatCycleLog(
            status: .estrus,
            recordedByHumanId: humanId,
            pet: pet
        )
        let weight = HumanWeightLog(weight: 70, human: human, executorId: humanId)
        let workout = HumanWorkoutLog(durationMinutes: 30, human: human)
        let metric = HumanHealthMetricLog(metricKey: "tsh", unitCode: "mIU_L", value: 2.1, human: human)
        let retainedMetric = HumanHealthMetricLog(
            metricKey: "hba1c",
            unitCode: "percent",
            value: 5.4,
            recordedByHumanId: humanId,
            human: survivor
        )
        let retainedReport = HumanHealthReport(
            humanId: survivor.id.uuidString,
            summary: "survivor report",
            recordedByHumanId: humanId
        )
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: humanId,
            displayName: human.name,
            balance: 10
        )
        let walletEntry = CoconutLedgerEntry(
            transactionKey: "human-delete-owned-wallet",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: humanId,
            ownerName: human.name,
            delta: 10,
            balanceBefore: 0,
            balanceAfter: 10,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "coconut",
            actorId: humanId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString
        )
        let careLedger = CareLedgerEvent(
            actorKind: .human,
            actorId: humanId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction
        )
        let budgetUsage = EconomyBudgetUsageEvent(
            dayKey: "2026-06-14",
            householdKey: "household",
            memberKey: humanId,
            careObjectKey: pet.id.uuidString,
            scope: .member,
            scopeKey: humanId,
            growthXPUsed: 1,
            coconutUsed: 2,
            actionKey: "feeding",
            source: "test"
        )
        let session = SharedCareSession(
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString],
            species: pet.species
        )
        session.setExecutorIds([humanId], primaryExecutorId: humanId)
        let undoReceipt = SharedCareUndoReceipt(
            sharedSessionId: session.id,
            sourcePetId: pet.id,
            targetPetIds: [pet.id],
            executorId: humanId,
            actionKind: .litterScoop,
            occurredAt: session.date,
            undoDeadline: session.date.addingTimeInterval(6)
        )
        let exchange = CoconutExchangeRequest(
            senderId: humanId,
            senderName: human.name,
            receiverId: survivor.id.uuidString,
            receiverName: survivor.name,
            coconutCost: 500,
            currencyCode: "USD",
            localAmount: 0.5
        )
        let task = FamilyCollaborationTask(
            title: "Human task",
            kind: .householdTask,
            createdById: humanId,
            createdByName: human.name,
            assignedToId: humanId,
            assignedToName: human.name
        )
        let humanSubjectTask = FamilyCollaborationTask(
            title: "Human subject task",
            kind: .householdTask,
            subjectKind: .human,
            subjectId: humanId,
            createdById: survivor.id.uuidString,
            createdByName: survivor.name,
            assignedToId: survivor.id.uuidString,
            assignedToName: survivor.name
        )
        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        context.insert(medication)
        context.insert(dose)
        context.insert(report)
        context.insert(wishlist)
        context.insert(ownedItem)
        context.insert(drawLog)
        context.insert(purchase)
        context.insert(privateExpense)
        context.insert(retainedPetExpense)
        context.insert(retainedHumanExpense)
        context.insert(retainedNoteRecord)
        context.insert(retainedSymptom)
        context.insert(retainedHeatCycle)
        context.insert(weight)
        context.insert(workout)
        context.insert(metric)
        context.insert(retainedMetric)
        context.insert(retainedReport)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        context.insert(budgetUsage)
        context.insert(session)
        context.insert(undoReceipt)
        context.insert(exchange)
        context.insert(task)
        context.insert(humanSubjectTask)
        try context.save()

        let deletedCount = PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivor.id.uuidString)
        try context.save()

        #expect(deletedCount > 0)
        #expect(try context.fetch(FetchDescriptor<Human>()).map(\.id) == [survivor.id])
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        let retainedHealthReports = try context.fetch(FetchDescriptor<HumanHealthReport>())
        #expect(retainedHealthReports.map(\.id) == [retainedReport.id])
        #expect(retainedHealthReports.first?.recordedByHumanId == nil)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaOwnedItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).isEmpty)
        let retainedExpenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        #expect(Set(retainedExpenses.map(\.id)) == Set([retainedPetExpense.id, retainedHumanExpense.id]))
        #expect(retainedExpenses.allSatisfy { $0.executorId == survivor.id.uuidString })
        #expect(retainedExpenses.allSatisfy { $0.recordedByHumanId == nil })
        let retainedNoteRecords = try context.fetch(FetchDescriptor<HumanNoteRecord>())
        #expect(retainedNoteRecords.map(\.id) == [retainedNoteRecord.id])
        #expect(retainedNoteRecords.first?.recordedByHumanId == nil)
        #expect(try context.fetch(FetchDescriptor<SymptomLog>()).first?.recordedByHumanId == nil)
        #expect(try context.fetch(FetchDescriptor<HeatCycleLog>()).first?.recordedByHumanId == nil)
        #expect(try context.fetch(FetchDescriptor<HumanWeightLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).isEmpty)
        let retainedHealthMetrics = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        #expect(retainedHealthMetrics.map(\.id) == [retainedMetric.id])
        #expect(retainedHealthMetrics.first?.recordedByHumanId == nil)
        let retiredAccount = try #require(try context.fetch(FetchDescriptor<CoconutAccount>()).first { $0.ownerId == humanId })
        #expect(retiredAccount.balance == 0)
        #expect(CoconutWalletAccountLifecycleMetadata.isDeletedOwner(retiredAccount))
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).map(\.id) == [walletEntry.id])
        #expect(CoconutWalletService.totalBalance(context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareUndoReceipt>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutExchangeRequest>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
        #expect(deletionTombstone(Human.self, id: human.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: reminder.id, context: context) != nil)
        #expect(deletionTombstone(EconomyBudgetUsageEvent.self, id: budgetUsage.id, context: context) != nil)
        #expect(deletionTombstone(CoconutExchangeRequest.self, id: exchange.id, context: context) != nil)
        #expect(deletionTombstone(FamilyCollaborationTask.self, id: task.id, context: context) != nil)
        #expect(deletionTombstone(FamilyCollaborationTask.self, id: humanSubjectTask.id, context: context) != nil)
    }

    @Test func deleteHumanUsesUnifiedResolverForMedicationNotesAndAssignments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let survivor = Human(name: "Ava")
        let pet = Pet(name: "Momo")
        let humanId = human.id.uuidString
        let medication = HumanMedication(humanId: humanId, name: "Vitamin")
        let medicationEvent = Event(
            title: "Human medication",
            eventType: EventType.medication.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
        let noteEvent = Event(
            title: "Human note",
            eventType: EventType.task.rawValue,
            relatedEntityType: DomainEntityLinkRegistry.humanNote,
            relatedEntityId: humanId
        )
        let retainedPetEvent = Event(
            title: "Pet task",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        retainedPetEvent.assigneeId = humanId
        let assignedOnlyEvent = Event(title: "Assigned household task", eventType: EventType.task.rawValue)
        assignedOnlyEvent.assigneeId = humanId
        let medicationReminder = Reminder(event: medicationEvent)
        let noteReminder = Reminder(event: noteEvent)
        let retainedReminder = Reminder(event: retainedPetEvent)
        let assignedOnlyReminder = Reminder(event: assignedOnlyEvent)
        medicationEvent.reminders = [medicationReminder]
        noteEvent.reminders = [noteReminder]
        retainedPetEvent.reminders = [retainedReminder]
        assignedOnlyEvent.reminders = [assignedOnlyReminder]

        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(medication)
        context.insert(medicationEvent)
        context.insert(noteEvent)
        context.insert(retainedPetEvent)
        context.insert(assignedOnlyEvent)
        context.insert(medicationReminder)
        context.insert(noteReminder)
        context.insert(retainedReminder)
        context.insert(assignedOnlyReminder)
        try context.save()

        PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivor.id.uuidString)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        #expect(events.map(\.id) == [retainedPetEvent.id])
        #expect(reminders.map(\.id) == [retainedReminder.id])
        #expect(events.first?.assigneeId == nil)
        #expect(deletionTombstone(Event.self, id: medicationEvent.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: noteEvent.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: assignedOnlyEvent.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: medicationReminder.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: noteReminder.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: assignedOnlyReminder.id, context: context) != nil)
    }

    @Test func deleteHumanDetachesSharedCareChildrenWhenOnlyExecutorSessionIsRemoved() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let survivor = Human(name: "Alex")
        let pet = Pet(name: "Momo")
        let humanId = human.id.uuidString
        let session = SharedCareSession(
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString],
            species: pet.species
        )
        session.setExecutorIds([humanId], primaryExecutorId: humanId)
        let careLog = PetCareLog(type: .feeding, sharedSessionId: session.id.uuidString, pet: pet, executorId: humanId)
        let pottyLog = PetPottyLog(type: .pee, pet: pet, executorId: humanId, sharedSessionId: session.id.uuidString)
        let hygieneLog = PetHygieneLog(type: .bath, pet: pet, executorId: humanId, sharedSessionId: session.id.uuidString)
        let expenseLog = PetExpenseLog(amount: 12, pet: pet, executorId: humanId, sharedSessionId: session.id.uuidString)
        let walkLog = PetWalkLog(pet: pet, executorId: humanId, executorIds: [humanId], sharedSessionId: session.id.uuidString)
        let careLedger = CareLedgerEvent(
            occurredAt: session.date,
            actorKind: .human,
            actorId: humanId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .service,
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: careLog.id.uuidString
        )

        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(session)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(expenseLog)
        context.insert(walkLog)
        context.insert(careLedger)
        try context.save()

        PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivor.id.uuidString)
        try context.save()

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(careLogs.map(\.id) == [careLog.id])
        #expect(pottyLogs.map(\.id) == [pottyLog.id])
        #expect(hygieneLogs.map(\.id) == [hygieneLog.id])
        #expect(expenseLogs.map(\.id) == [expenseLog.id])
        #expect(walkLogs.map(\.id) == [walkLog.id])
        #expect(careLogs.first?.sharedSessionId == "")
        #expect(pottyLogs.first?.sharedSessionId == "")
        #expect(hygieneLogs.first?.sharedSessionId == "")
        #expect(expenseLogs.first?.sharedSessionId == "")
        #expect(walkLogs.first?.sharedSessionId == "")
        #expect(careLogs.first?.executorId == nil)
        #expect(pottyLogs.first?.executorId == nil)
        #expect(hygieneLogs.first?.executorId == nil)
        #expect(expenseLogs.first?.executorId == nil)
        #expect(walkLogs.first?.executorId == nil)
        #expect(walkLogs.first?.executorIds.isEmpty == true)
        #expect(ledgers.map(\.id) == [careLedger.id])
        #expect(ledgers.first?.actorKind == CareLedgerActorKind.unknown.rawValue)
        #expect(ledgers.first?.actorId == nil)
        #expect(deletionTombstone(SharedCareSession.self, id: session.id, context: context) != nil)
    }

    @Test func deleteHumanScrubsExecutorFromRetainedPetFactsAndLedgers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let survivor = Human(name: "Alex")
        let pet = Pet(name: "Momo")
        let humanId = human.id.uuidString
        let petId = pet.id.uuidString
        let occurredAt = Date(timeIntervalSinceReferenceDate: 1000)

        let careLog = PetCareLog(date: occurredAt, type: .feeding, pet: pet, executorId: humanId)
        let pottyLog = PetPottyLog(date: occurredAt, type: .pee, pet: pet, executorId: humanId)
        let hygieneLog = PetHygieneLog(date: occurredAt, type: .bath, pet: pet, executorId: humanId)
        let healthLog = PetHealthLog(date: occurredAt, type: .vaccine, pet: pet, executorId: humanId)
        let walkLog = PetWalkLog(startDate: occurredAt, pet: pet, executorId: humanId, executorIds: [humanId])
        let weightLog = PetWeightLog(date: occurredAt, weight: 6.2, pet: pet, executorId: humanId)
        let foodRecord = PetFoodRecord(
            brand: "Kibble",
            dailyGrams: 80,
            totalGrams: 1000,
            startDate: occurredAt,
            pet: pet,
            executorId: humanId
        )
        let expenseLog = PetExpenseLog(date: occurredAt, amount: 12, pet: pet, executorId: humanId)

        let factKeys = [
            ("PetCareLog", careLog.id.uuidString, CareLedgerEventKind.care, CareType.feeding.rawValue),
            ("PetPottyLog", pottyLog.id.uuidString, CareLedgerEventKind.potty, PottyType.pee.rawValue),
            ("PetHygieneLog", hygieneLog.id.uuidString, CareLedgerEventKind.hygiene, HygieneType.bath.rawValue),
            ("PetHealthLog", healthLog.id.uuidString, CareLedgerEventKind.health, HealthLogType.vaccine.rawValue),
            ("PetWalkLog", walkLog.id.uuidString, CareLedgerEventKind.walk, "walk"),
            ("PetWeightLog", weightLog.id.uuidString, CareLedgerEventKind.weight, "weight"),
            ("PetFoodRecord", foodRecord.id.uuidString, CareLedgerEventKind.care, CareType.feeding.rawValue),
            ("PetExpenseLog", expenseLog.id.uuidString, CareLedgerEventKind.expense, ExpenseCategory.other.rawValue)
        ]
        let careLedgerEvents = factKeys.map { modelName, modelId, eventKind, actionType in
            CareLedgerEvent(
                occurredAt: occurredAt,
                actorKind: .human,
                actorId: humanId,
                subjectKind: .pet,
                subjectId: petId,
                eventKind: eventKind,
                actionType: actionType,
                source: .service,
                legacyModelName: modelName,
                legacyModelId: modelId
            )
        }
        let coconutAccount = CoconutAccount(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: petId,
            displayName: pet.name,
            balance: 3
        )
        let coconutLedger = CoconutLedgerEntry(
            transactionKey: "retained-pet-reward",
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: petId,
            ownerName: pet.name,
            delta: 3,
            balanceBefore: 0,
            balanceAfter: 3,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "🥥",
            actorId: humanId,
            actorName: human.name,
            subjectKind: .pet,
            subjectId: petId,
            sourceModelName: "PetCareLog",
            sourceModelId: careLog.id.uuidString,
            careLedgerEventId: careLedgerEvents.first?.id.uuidString
        )

        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(healthLog)
        context.insert(walkLog)
        context.insert(weightLog)
        context.insert(foodRecord)
        context.insert(expenseLog)
        context.insert(coconutAccount)
        context.insert(coconutLedger)
        careLedgerEvents.forEach(context.insert)
        try context.save()

        PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivor.id.uuidString)
        try context.save()

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let healthLogs = try context.fetch(FetchDescriptor<PetHealthLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let weightLogs = try context.fetch(FetchDescriptor<PetWeightLog>())
        let foodRecords = try context.fetch(FetchDescriptor<PetFoodRecord>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let coconutLedgers = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())

        #expect(careLogs.map(\.id) == [careLog.id])
        #expect(pottyLogs.map(\.id) == [pottyLog.id])
        #expect(hygieneLogs.map(\.id) == [hygieneLog.id])
        #expect(healthLogs.map(\.id) == [healthLog.id])
        #expect(walkLogs.map(\.id) == [walkLog.id])
        #expect(weightLogs.map(\.id) == [weightLog.id])
        #expect(foodRecords.map(\.id) == [foodRecord.id])
        #expect(expenseLogs.map(\.id) == [expenseLog.id])
        #expect(careLogs.first?.executorId == nil)
        #expect(pottyLogs.first?.executorId == nil)
        #expect(hygieneLogs.first?.executorId == nil)
        #expect(healthLogs.first?.executorId == nil)
        #expect(walkLogs.first?.executorId == nil)
        #expect(walkLogs.first?.executorIds.isEmpty == true)
        #expect(weightLogs.first?.executorId == nil)
        #expect(foodRecords.first?.executorId == nil)
        #expect(expenseLogs.first?.executorId == nil)

        #expect(Set(ledgers.map(\.id)) == Set(careLedgerEvents.map(\.id)))
        #expect(ledgers.allSatisfy { $0.actorKind == CareLedgerActorKind.unknown.rawValue })
        #expect(ledgers.allSatisfy { $0.actorId == nil })
        #expect(ledgers.allSatisfy { $0.subjectId == petId })
        #expect(coconutLedgers.map(\.id) == [coconutLedger.id])
        #expect(coconutLedgers.first?.actorId == nil)
        #expect(coconutLedgers.first?.actorName == nil)

        try CareLedgerBackfillService.backfill(context: context)
        try context.save()
        let ledgersAfterBackfill = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(Set(ledgersAfterBackfill.map(\.id)) == Set(careLedgerEvents.map(\.id)))
        #expect(ledgersAfterBackfill.allSatisfy { $0.actorId != humanId })

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: context)
        #expect(backup.petCareLogs.first { $0.id == careLog.id.uuidString }?.executorId == nil)
        #expect(backup.petPottyLogs.first { $0.id == pottyLog.id.uuidString }?.executorId == nil)
        #expect(backup.petHygieneLogs.first { $0.id == hygieneLog.id.uuidString }?.executorId == nil)
        #expect(backup.petHealthLogs.first { $0.id == healthLog.id.uuidString }?.executorId == nil)
        #expect(backup.petWalkLogs.first { $0.id == walkLog.id.uuidString }?.executorId == nil)
        #expect(backup.petWalkLogs.first { $0.id == walkLog.id.uuidString }?.executorIdsRaw == nil)
        #expect(backup.petWeightLogs.first { $0.id == weightLog.id.uuidString }?.executorId == nil)
        #expect(backup.petFoodRecords.first { $0.id == foodRecord.id.uuidString }?.executorId == nil)
        #expect(backup.petExpenseLogs.first { $0.id == expenseLog.id.uuidString }?.executorId == nil)
        #expect((backup.careLedgerEvents ?? []).allSatisfy { $0.actorId != humanId })
        #expect((backup.coconutLedgerEntries ?? []).allSatisfy { $0.actorId != humanId })
    }

    @Test func deleteHumanScrubsSharedCareChildrenWhenSessionKeepsOtherExecutors() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let survivor = Human(name: "Alex")
        let pet = Pet(name: "Momo")
        let humanId = human.id.uuidString
        let survivorId = survivor.id.uuidString
        let session = SharedCareSession(
            actionKind: .walk,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString],
            species: pet.species
        )
        session.setExecutorIds([humanId, survivorId], primaryExecutorId: humanId)
        let careLog = PetCareLog(type: .play, sharedSessionId: session.id.uuidString, pet: pet, executorId: humanId)
        let pottyLog = PetPottyLog(type: .pee, pet: pet, executorId: humanId, sharedSessionId: session.id.uuidString)
        let hygieneLog = PetHygieneLog(type: .bath, pet: pet, executorId: humanId, sharedSessionId: session.id.uuidString)
        let expenseLog = PetExpenseLog(amount: 12, pet: pet, executorId: humanId, sharedSessionId: session.id.uuidString)
        let walkLog = PetWalkLog(pet: pet, executorId: humanId, executorIds: [humanId, survivorId], sharedSessionId: session.id.uuidString)
        let careLedger = CareLedgerEvent(
            occurredAt: session.date,
            actorKind: .human,
            actorId: humanId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.play.rawValue,
            source: .service,
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: careLog.id.uuidString
        )

        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(session)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(expenseLog)
        context.insert(walkLog)
        context.insert(careLedger)
        try context.save()

        PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivorId)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let ledgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())

        #expect(sessions.map(\.id) == [session.id])
        #expect(sessions.first?.executorIds == [survivorId])
        #expect(careLogs.first?.sharedSessionId == session.id.uuidString)
        #expect(pottyLogs.first?.sharedSessionId == session.id.uuidString)
        #expect(hygieneLogs.first?.sharedSessionId == session.id.uuidString)
        #expect(expenseLogs.first?.sharedSessionId == session.id.uuidString)
        #expect(walkLogs.first?.sharedSessionId == session.id.uuidString)
        #expect(careLogs.first?.executorId == survivorId)
        #expect(pottyLogs.first?.executorId == survivorId)
        #expect(hygieneLogs.first?.executorId == survivorId)
        #expect(expenseLogs.first?.executorId == survivorId)
        #expect(walkLogs.first?.executorId == survivorId)
        #expect(walkLogs.first?.executorIds == [survivorId])
        #expect(ledgers.map(\.id) == [careLedger.id])
        #expect(ledgers.first?.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(ledgers.first?.actorId == survivorId)
    }

    @Test func careLedgerRecordEnqueuesCloudSyncDirtyState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = CareLedgerService.record(
            occurredAt: Date(timeIntervalSinceReferenceDate: 20),
            subjectKind: .pet,
            subjectId: UUID().uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            context: context
        )

        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: CareLedgerEvent.self),
            localRecordId: event.id,
            context: context
        ))
        #expect(state.hasPendingLocalChanges)
        #expect(!state.isDeletionTombstone)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV91.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func deletionTombstone<T>(
        _: T.Type,
        id: UUID,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        let key = CloudSyncRecordState.recordKey(entityName: String(describing: T.self), localRecordId: id)
        return (try? context.fetch(FetchDescriptor<CloudSyncRecordState>()))?
            .first { $0.recordKey == key && $0.isDeletionTombstone }
    }
}
