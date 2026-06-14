import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct PhysicalDeletionServiceTests {
    @Test func physicalDeletionCoverageMatchesCloudSyncRegistryOwnershipManifest() {
        #expect(
            PhysicalDeletionService.localPhysicalDeletionCascadeCoverage(parent: .pet) ==
                CloudSyncEntityRegistry.physicalDeletionOwnedEntityNames(parent: .pet)
        )
        #expect(
            PhysicalDeletionService.localPhysicalDeletionCascadeCoverage(parent: .human) ==
                CloudSyncEntityRegistry.physicalDeletionOwnedEntityNames(parent: .human)
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

    @Test func deletePetRemovesWalletLedgerAndSharedSessionReferences() throws {
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
        context.insert(deletedPet)
        context.insert(survivor)
        context.insert(session)
        context.insert(deletedLog)
        context.insert(survivorLog)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        try context.save()

        PhysicalDeletionService.deletePet(deletedPet, context: context)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(accounts.allSatisfy { $0.ownerId != deletedPet.id.uuidString })
        #expect(walletEntries.allSatisfy { $0.ownerId != deletedPet.id.uuidString && $0.subjectId != deletedPet.id.uuidString })
        #expect(careLedgers.allSatisfy { $0.subjectId != deletedPet.id.uuidString && $0.legacyModelId != deletedLog.id.uuidString })
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
        #expect(sessions.first?.totalAmountGrams == survivorLog.amountGrams)
        #expect(CoconutWalletService.totalBalance(context: context) == 0)
        #expect(deletionTombstone(CoconutLedgerEntry.self, id: walletEntry.id, context: context) != nil)
        #expect(deletionTombstone(CareLedgerEvent.self, id: careLedger.id, context: context) != nil)
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
        #expect(try context.fetch(FetchDescriptor<CoconutAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(deletionTombstone(Pet.self, id: pet.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: reminder.id, context: context) != nil)
        #expect(deletionTombstone(PetRelationship.self, id: relationship.id, context: context) != nil)
        #expect(deletionTombstone(FamilyCollaborationTask.self, id: task.id, context: context) != nil)
        #expect(deletionTombstone(EconomyBudgetUsageEvent.self, id: budgetUsage.id, context: context) != nil)
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
        let weight = HumanWeightLog(weight: 70, human: human, executorId: humanId)
        let workout = HumanWorkoutLog(durationMinutes: 30, human: human)
        let metric = HumanHealthMetricLog(metricKey: "tsh", unitCode: "mIU_L", value: 2.1, human: human)
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
        context.insert(weight)
        context.insert(workout)
        context.insert(metric)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        context.insert(budgetUsage)
        context.insert(session)
        context.insert(exchange)
        context.insert(task)
        try context.save()

        let deletedCount = PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivor.id.uuidString)
        try context.save()

        #expect(deletedCount > 0)
        #expect(try context.fetch(FetchDescriptor<Human>()).map(\.id) == [survivor.id])
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Reminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaOwnedItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaDrawLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanWeightLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CoconutExchangeRequest>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FamilyCollaborationTask>()).isEmpty)
        #expect(deletionTombstone(Human.self, id: human.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: reminder.id, context: context) != nil)
        #expect(deletionTombstone(EconomyBudgetUsageEvent.self, id: budgetUsage.id, context: context) != nil)
        #expect(deletionTombstone(CoconutExchangeRequest.self, id: exchange.id, context: context) != nil)
        #expect(deletionTombstone(FamilyCollaborationTask.self, id: task.id, context: context) != nil)
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

        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(session)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(expenseLog)
        context.insert(walkLog)
        try context.save()

        PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivor.id.uuidString)
        try context.save()

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())

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
        #expect(deletionTombstone(SharedCareSession.self, id: session.id, context: context) != nil)
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

        context.insert(human)
        context.insert(survivor)
        context.insert(pet)
        context.insert(session)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(hygieneLog)
        context.insert(expenseLog)
        context.insert(walkLog)
        try context.save()

        PhysicalDeletionService.deleteHuman(human, context: context, deletedByHumanId: survivorId)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let hygieneLogs = try context.fetch(FetchDescriptor<PetHygieneLog>())
        let expenseLogs = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())

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
        let schema = Schema(ArkSchemaV72.models)
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
