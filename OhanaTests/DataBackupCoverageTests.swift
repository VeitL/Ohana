import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct DataBackupCoverageTests {
    @Test func latestSwiftDataModelsHaveExternalBackupCoverageOrExplicitHealthExemption() {
        let schemaModels = Set(ArkSchemaV90.models.map { String(describing: $0) })
        let externallyCoveredModels: Set<String> = [
            String(describing: Pet.self),
            String(describing: Human.self),
            String(describing: Plant.self),
            String(describing: Household.self),
            String(describing: Event.self),
            String(describing: Reminder.self),
            String(describing: PetPottyLog.self),
            String(describing: PetWalkLog.self),
            String(describing: PetHygieneLog.self),
            String(describing: PetWeightLog.self),
            String(describing: PetHealthLog.self),
            String(describing: PetDocument.self),
            String(describing: PetExpenseLog.self),
            String(describing: PetFoodRecord.self),
            String(describing: PetMilestone.self),
            String(describing: WaterLog.self),
            String(describing: PetRelationship.self),
            String(describing: PetCareLog.self),
            String(describing: WishlistItem.self),
            String(describing: PetDocumentAttachment.self),
            String(describing: PetMedication.self),
            String(describing: PetInsurance.self),
            String(describing: PetPhotoLog.self),
            String(describing: PlantCareLog.self),
            String(describing: SymptomLog.self),
            String(describing: HeatCycleLog.self),
            String(describing: InsuranceClaim.self),
            String(describing: CareLedgerEvent.self),
            String(describing: CoconutExchangeRequest.self),
            String(describing: OasisUpgradeCoconut.self),
            String(describing: OasisElectronicPet.self),
            String(describing: OasisCritterFragmentBalance.self),
            String(describing: OasisUnlock.self),
            String(describing: OasisCritterActionLog.self),
            String(describing: SharedCareSession.self),
            String(describing: GachaOwnedItem.self),
            String(describing: GachaDrawLog.self),
            String(describing: CoconutAccount.self),
            String(describing: ShopPurchaseRecord.self)
        ]
        let intentionallyExcludedFromExternalBackup: Set<String> = [
            // P0: no human health / HealthKit data may enter an externally
            // shareable package such as iCloud Drive or Files providers.
            String(describing: HumanWeightLog.self),
            String(describing: HumanWorkoutLog.self),
            String(describing: HumanMedication.self),
            String(describing: HumanMedicationLog.self),
            String(describing: HumanHealthReport.self),
            String(describing: HumanHealthMetricLog.self),
            // Family-task text is free-form and legacy tasks may not link to
            // a structured source, so restricted external exports omit it.
            String(describing: FamilyCollaborationTask.self),
            // Derived economy sidecars retain free-form titles/metadata but
            // their legacy schema cannot prove whether a record repeats a
            // Human health fact. Restricted external packages omit them.
            String(describing: CoconutLedgerEntry.self),
            String(describing: EconomyBudgetUsageEvent.self),
            String(describing: CloudSyncRecordState.self),
            String(describing: RecycleBinBatch.self),
            // Local crash-recovery coordination state is neither a user fact
            // nor safe to resurrect from a stale external backup.
            String(describing: SharedCareUndoReceipt.self)
        ]
        let classifiedModels = externallyCoveredModels.union(intentionallyExcludedFromExternalBackup)
        let missingModels = schemaModels.subtracting(classifiedModels)
        let staleCoverageModels = externallyCoveredModels.subtracting(schemaModels)
        let staleExemptModels = intentionallyExcludedFromExternalBackup.subtracting(schemaModels)

        if !missingModels.isEmpty {
            Issue.record("SwiftData models missing external backup coverage or explicit classification: \(missingModels.sorted())")
        }
        if !staleCoverageModels.isEmpty {
            Issue.record("External backup coverage lists models no longer in ArkSchemaV90: \(staleCoverageModels.sorted())")
        }
        if !staleExemptModels.isEmpty {
            Issue.record("External backup exclusion list contains stale models: \(staleExemptModels.sorted())")
        }

        #expect(missingModels.isEmpty)
        #expect(staleCoverageModels.isEmpty)
        #expect(staleExemptModels.isEmpty)
        #expect(schemaModels == classifiedModels)
    }

    @Test func restrictedBackupPreservesPetRelationshipAndOmitsEconomyBudgetUsageEvents() throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let createdAt = Date(timeIntervalSinceReferenceDate: 7000)
        let occurredAt = Date(timeIntervalSinceReferenceDate: 7500)
        let human = Human(name: "Guan")
        human.id = try #require(UUID(uuidString: "11111111-1111-4111-8111-111111111111"))
        let firstPet = Pet(name: "Miso", species: "猫")
        firstPet.id = try #require(UUID(uuidString: "22222222-2222-4222-8222-222222222222"))
        let secondPet = Pet(name: "Luna", species: "猫")
        secondPet.id = try #require(UUID(uuidString: "33333333-3333-4333-8333-333333333333"))
        let relationship = PetRelationship(
            fromPetId: firstPet.id,
            toPetId: secondPet.id,
            type: .sibling,
            note: "same litter"
        )
        relationship.id = try #require(UUID(uuidString: "44444444-4444-4444-8444-444444444444"))
        relationship.createdAt = createdAt
        let budgetEvent = EconomyBudgetUsageEvent(
            id: try #require(UUID(uuidString: "55555555-5555-4555-8555-555555555555")),
            dayKey: "2026-07-07",
            householdKey: "household",
            memberKey: human.id.uuidString,
            careObjectKey: firstPet.id.uuidString,
            scope: .careObject,
            scopeKey: firstPet.id.uuidString,
            growthXPUsed: 3,
            coconutUsed: 5,
            luckyCoconutUsed: 1,
            actionKey: "feeding",
            source: "test",
            metadataJSON: #"{"kind":"coverage"}"#,
            occurredAt: occurredAt,
            createdAt: createdAt
        )
        sourceContext.insert(human)
        sourceContext.insert(firstPet)
        sourceContext.insert(secondPet)
        sourceContext.insert(relationship)
        sourceContext.insert(budgetEvent)
        try sourceContext.save()

        let backup = try TestDataBackupManagerProjection.manager.buildBackup(context: sourceContext)

        #expect(backup.petRelationships?.count == 1)
        #expect(backup.petRelationships?.first?.relationshipTypeRaw == PetRelationshipType.sibling.rawValue)
        #expect(backup.exportScope == DataBackupExportScope.manualExternalRestricted.rawValue)
        #expect(backup.economyBudgetUsageEvents?.isEmpty == true)

        let target = try makeInMemoryContainer()
        try TestDataBackupManagerProjection.manager.applyBackup(
            backup,
            context: target.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false
        )

        let restoredRelationship = try #require(try target.mainContext.fetch(FetchDescriptor<PetRelationship>()).first)

        #expect(restoredRelationship.id == relationship.id)
        #expect(restoredRelationship.fromPetId == firstPet.id)
        #expect(restoredRelationship.toPetId == secondPet.id)
        #expect(restoredRelationship.relationshipTypeRaw == PetRelationshipType.sibling.rawValue)
        #expect(restoredRelationship.note == "same litter")
        #expect(restoredRelationship.createdAt == createdAt)
        #expect(try target.mainContext.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
    }

    @Test func backupPackageRoundTripsAllExternalStorageMediaFields() async throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let petAvatar = Data([10, 11, 12])
        let plantAvatar = Data([20, 21, 22])
        let walkMapSnapshot = Data([30, 31, 32])
        let walkRouteLocations = Data([40, 41, 42])
        let milestonePhoto = Data([50, 51, 52])

        let pet = Pet(name: "Miso", species: "猫")
        pet.id = try #require(UUID(uuidString: "66666666-6666-4666-8666-666666666666"))
        pet.updateAvatarImageData(petAvatar)

        let plant = Plant(name: "Monstera", species: "Monstera")
        plant.id = try #require(UUID(uuidString: "77777777-7777-4777-8777-777777777777"))
        plant.updateAvatarImageData(plantAvatar)

        let walkLog = PetWalkLog(
            startDate: Date(timeIntervalSinceReferenceDate: 8000),
            pet: pet,
            executorId: "human-1"
        )
        walkLog.id = try #require(UUID(uuidString: "88888888-8888-4888-8888-888888888888"))
        walkLog.endDate = Date(timeIntervalSinceReferenceDate: 8600)
        walkLog.distanceMeters = 1234
        walkLog.mapSnapshotData = walkMapSnapshot
        walkLog.routeLocationsData = walkRouteLocations

        let milestone = PetMilestone(
            date: Date(timeIntervalSinceReferenceDate: 9000),
            title: "First climb",
            emoji: "star",
            notes: "window ledge",
            pet: pet,
            photoData: milestonePhoto,
            location: "living room"
        )
        milestone.id = try #require(UUID(uuidString: "99999999-9999-4999-8999-999999999999"))

        sourceContext.insert(pet)
        sourceContext.insert(plant)
        sourceContext.insert(walkLog)
        sourceContext.insert(milestone)
        try sourceContext.save()

        let packageURL = try await TestDataBackupManagerProjection.manager.exportJSON(container: source)
        let manifest = try #require(String(data: backupManifestData(from: packageURL), encoding: .utf8))

        #expect(packageURL.pathExtension == DataBackupManager.packageFileExtension)
        #expect(manifest.contains("\"avatarImageRef\""))
        #expect(manifest.contains("\"mapSnapshotRef\""))
        #expect(manifest.contains("\"routeLocationsRef\""))
        #expect(manifest.contains("\"photoRef\""))
        #expect(manifest.contains("pet-avatar-"))
        #expect(manifest.contains("plant-avatar-"))
        #expect(manifest.contains("pet-walk-map-snapshot-"))
        #expect(manifest.contains("pet-walk-route-locations-"))
        #expect(manifest.contains("pet-milestone-photo-"))
        #expect(!manifest.contains(petAvatar.base64EncodedString()))
        #expect(!manifest.contains(plantAvatar.base64EncodedString()))
        #expect(!manifest.contains(walkMapSnapshot.base64EncodedString()))
        #expect(!manifest.contains(walkRouteLocations.base64EncodedString()))
        #expect(!manifest.contains(milestonePhoto.base64EncodedString()))

        let target = try makeInMemoryContainer()
        let targetContext = target.mainContext
        try await TestDataBackupManagerProjection.manager.importJSON(
            from: packageURL,
            context: targetContext,
            schedulePlantNotifications: false
        )

        let restoredPet = try #require(try targetContext.fetch(FetchDescriptor<Pet>()).first)
        let restoredPlant = try #require(try targetContext.fetch(FetchDescriptor<Plant>()).first)
        let restoredWalk = try #require(try targetContext.fetch(FetchDescriptor<PetWalkLog>()).first)
        let restoredMilestone = try #require(try targetContext.fetch(FetchDescriptor<PetMilestone>()).first)

        #expect(restoredPet.avatarImageData == petAvatar)
        #expect(restoredPlant.avatarImageData == plantAvatar)
        #expect(restoredWalk.mapSnapshotData == walkMapSnapshot)
        #expect(restoredWalk.routeLocationsData == walkRouteLocations)
        #expect(restoredMilestone.photoData == milestonePhoto)
        #expect(restoredMilestone.location == "living room")
        #expect(restoredPet.hasAvatarImageAttachment)
        #expect(restoredPlant.hasAvatarImageAttachment)
        #expect(restoredMilestone.hasPhotoAttachment)
    }

    @Test func familyTaskSubjectCodecRehydratesV87PlantAndLegacyV86PetLinks() throws {
        let manager = TestDataBackupManagerProjection.manager
        let creator = Human(name: "Publisher")
        let assignee = Human(name: "Assignee")
        let plant = Plant(name: "Fern")
        let pet = Pet(name: "Momo", species: "cat")
        let plantTask = FamilyCollaborationTask(
            title: "Water fern",
            kind: .bounty,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name,
            rewardCoconuts: 7
        )
        let legacyPetTask = FamilyCollaborationTask(
            title: "Feed Momo",
            kind: .careReminder,
            relatedPetId: pet.id.uuidString,
            createdById: creator.id.uuidString,
            createdByName: creator.name,
            assignedToId: assignee.id.uuidString,
            assignedToName: assignee.name
        )

        let plantDTO = manager.encodeFamilyCollaborationTask(plantTask)
        #expect(plantDTO.subjectKindRaw == FamilyCollaborationTaskSubjectKind.plant.rawValue)
        #expect(plantDTO.subjectId == plant.id.uuidString)
        #expect(plantDTO.relatedPetId == nil)

        let encodedLegacyDTO = try JSONEncoder().encode(manager.encodeFamilyCollaborationTask(legacyPetTask))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedLegacyDTO) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "subjectKindRaw")
        legacyObject.removeValue(forKey: "subjectId")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let decodedLegacyDTO = try JSONDecoder().decode(FamilyCollaborationTaskBackup.self, from: legacyData)
        #expect(decodedLegacyDTO.subjectKindRaw == nil)
        #expect(decodedLegacyDTO.subjectId == nil)
        #expect(decodedLegacyDTO.relatedPetId == pet.id.uuidString)

        let target = try makeInMemoryContainer()
        let context = target.mainContext
        let restoredCreator = Human(name: creator.name)
        restoredCreator.id = creator.id
        let restoredAssignee = Human(name: assignee.name)
        restoredAssignee.id = assignee.id
        let restoredPlant = Plant(name: plant.name)
        restoredPlant.id = plant.id
        let restoredPet = Pet(name: pet.name, species: pet.species)
        restoredPet.id = pet.id
        context.insert(restoredCreator)
        context.insert(restoredAssignee)
        context.insert(restoredPlant)
        context.insert(restoredPet)
        try context.save()

        let plantResult = try DomainGeneralRehydrateWriter.insertFamilyCollaborationTaskIfNeeded(
            snapshot: manager.decodeFamilyCollaborationTaskSnapshot(plantDTO),
            source: .backupRestore,
            context: context
        )
        let legacyResult = try DomainGeneralRehydrateWriter.insertFamilyCollaborationTaskIfNeeded(
            snapshot: manager.decodeFamilyCollaborationTaskSnapshot(decodedLegacyDTO),
            source: .backupRestore,
            context: context
        )
        let restoredPlantTask = try #require(plantResult.model)
        let restoredLegacyPetTask = try #require(legacyResult.model)

        #expect(plantResult.didPersist)
        #expect(restoredPlantTask.subjectKind == .plant)
        #expect(restoredPlantTask.resolvedSubjectId == plant.id.uuidString)
        #expect(restoredPlantTask.relatedPetId == nil)
        #expect(legacyResult.didPersist)
        #expect(restoredLegacyPetTask.subjectKind == .pet)
        #expect(restoredLegacyPetTask.resolvedSubjectId == pet.id.uuidString)
        #expect(restoredLegacyPetTask.relatedPetId == pet.id.uuidString)
    }

    @Test func eventTaskCareKindCodecRehydratesV88AndDefaultsLegacyBackupToEmpty() throws {
        let manager = TestDataBackupManagerProjection.manager
        let event = Event(
            title: "Scoop litter",
            startDate: Date(timeIntervalSince1970: 1_900_000_000),
            eventType: EventType.task.rawValue
        )
        event.taskCareKindRaw = "litterBox"

        let dto = manager.encodeEvent(event)
        #expect(dto.taskCareKindRaw == "litterBox")
        #expect(manager.decodeEventSnapshot(dto).taskCareKindRaw == "litterBox")

        let encodedDTO = try JSONEncoder().encode(dto)
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedDTO) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "taskCareKindRaw")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDTO = try JSONDecoder().decode(EventBackup.self, from: legacyData)
        #expect(legacyDTO.taskCareKindRaw == nil)
        #expect(manager.decodeEventSnapshot(legacyDTO).taskCareKindRaw.isEmpty)

        let target = try makeInMemoryContainer()
        let legacyResult = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: manager.decodeEventSnapshot(legacyDTO),
            source: .backupRestore,
            context: target.mainContext
        )
        let restoredLegacyEvent = try #require(legacyResult.event)
        #expect(legacyResult.plan.disposition.allowsPersistence)
        #expect(restoredLegacyEvent.taskCareKindRaw.isEmpty)

        let result = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: manager.decodeEventSnapshot(dto),
            source: .backupRestore,
            context: target.mainContext
        )
        let restoredEvent = try #require(result.event)

        #expect(result.plan.disposition.allowsPersistence)
        #expect(restoredEvent.taskCareKindRaw == "litterBox")
    }

    @Test func reminderOccurrenceCodecRehydratesV89AndDefaultsLegacyBackupToDeliveryTime() throws {
        let manager = TestDataBackupManagerProjection.manager
        let event = Event(title: "Water", startDate: Date(timeIntervalSince1970: 1_900_000_000))
        let occurrence = event.startDate
        let reminder = Reminder(
            event: event,
            scheduledAt: occurrence.addingTimeInterval(-3600),
            occurrenceAt: occurrence
        )

        let dto = manager.encodeReminder(reminder)
        #expect(dto.occurrenceAt != nil)
        #expect(manager.decodeReminderSnapshot(dto).occurrenceAt == occurrence)

        let encodedDTO = try JSONEncoder().encode(dto)
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedDTO) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "occurrenceAt")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDTO = try JSONDecoder().decode(ReminderBackup.self, from: legacyData)
        #expect(legacyDTO.occurrenceAt == nil)
        #expect(manager.decodeReminderSnapshot(legacyDTO).occurrenceAt == nil)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV90.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, configurations: [config])
    }

    private func backupManifestData(from packageURL: URL) throws -> Data {
        try Data(contentsOf: packageURL.appendingPathComponent(DataBackupManager.manifestFileName, isDirectory: false))
    }
}
