import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct DataBackupCoverageTests {
    @Test func latestSwiftDataModelsHaveExternalBackupCoverageOrExplicitHealthExemption() {
        let schemaModels = Set(ArkSchemaV94.models.map { String(describing: $0) })
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
            String(describing: ShopPurchaseRecord.self),
            String(describing: PresenceCheckIn.self),
            String(describing: PresenceParticipationPeriod.self),
            String(describing: PresenceRewardReceipt.self),
            String(describing: AchievementUnlock.self),
            String(describing: AchievementRewardReceipt.self)
        ]
        let intentionallyExcludedFromExternalBackup: Set<String> = [
            // P0: no human health / HealthKit data may enter an externally
            // shareable package such as iCloud Drive or Files providers.
            String(describing: HumanWeightLog.self),
            String(describing: HumanWorkoutLog.self),
            String(describing: HumanMedication.self),
            String(describing: HumanMedicationLog.self),
            String(describing: HumanHealthReport.self),
            String(describing: HumanNoteRecord.self),
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
            String(describing: SharedCareUndoReceipt.self),
            String(describing: ShopPurchaseAttempt.self),
            // Safety contacts and phone numbers are explicitly device-local
            // and excluded from every backup/export destination.
            String(describing: SafetyContact.self)
        ]
        let classifiedModels = externallyCoveredModels.union(intentionallyExcludedFromExternalBackup)
        let missingModels = schemaModels.subtracting(classifiedModels)
        let staleCoverageModels = externallyCoveredModels.subtracting(schemaModels)
        let staleExemptModels = intentionallyExcludedFromExternalBackup.subtracting(schemaModels)

        if !missingModels.isEmpty {
            Issue.record("SwiftData models missing external backup coverage or explicit classification: \(missingModels.sorted())")
        }
        if !staleCoverageModels.isEmpty {
            Issue.record("External backup coverage lists models no longer in ArkSchemaV94: \(staleCoverageModels.sorted())")
        }
        if !staleExemptModels.isEmpty {
            Issue.record("External backup exclusion list contains stale models: \(staleExemptModels.sorted())")
        }

        #expect(missingModels.isEmpty)
        #expect(staleCoverageModels.isEmpty)
        #expect(staleExemptModels.isEmpty)
        #expect(schemaModels == classifiedModels)
    }

    @Test func expenseRecorderAttributionRoundTripsAndLegacyBackupDefaultsToNil() throws {
        let manager = TestDataBackupManagerProjection.manager
        let log = PetExpenseLog(
            amount: 42,
            category: .food,
            note: "shared bag",
            executorId: "payer-id",
            recordedByHumanId: "recorder-id"
        )

        let dto = manager.encodeExpenseLog(log)
        #expect(dto.executorId == "payer-id")
        #expect(dto.recordedByHumanId == "recorder-id")
        #expect(manager.decodeExpenseLogSnapshot(dto).recordedByHumanId == "recorder-id")

        let encodedDTO = try JSONEncoder().encode(dto)
        var legacyObject = try #require(JSONSerialization.jsonObject(with: encodedDTO) as? [String: Any])
        legacyObject.removeValue(forKey: "recordedByHumanId")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDTO = try JSONDecoder().decode(PetExpenseLogBackup.self, from: legacyData)
        #expect(manager.decodeExpenseLogSnapshot(legacyDTO).recordedByHumanId == nil)
    }

    @Test func humanHealthRecorderAttributionRoundTripsAndLegacyBackupDefaultsToNil() throws {
        let manager = TestDataBackupManagerProjection.manager
        let human = Human(name: "Guan")
        let recorderID = UUID().uuidString
        let metric = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 3.2,
            recordedByHumanId: recorderID,
            human: human
        )
        let report = HumanHealthReport(
            humanId: human.id.uuidString,
            recordedByHumanId: recorderID
        )

        let metricDTO = manager.encodeHumanHealthMetricLog(metric)
        let reportDTO = manager.encodeHumanHealthReport(report)
        #expect(manager.decodeHumanHealthMetricLogSnapshot(metricDTO).recordedByHumanId == recorderID)
        #expect(manager.decodeHumanHealthReportSnapshot(reportDTO).recordedByHumanId == recorderID)

        var legacyMetricObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(metricDTO)) as? [String: Any]
        )
        legacyMetricObject.removeValue(forKey: "recordedByHumanId")
        let legacyMetricDTO = try JSONDecoder().decode(
            HumanHealthMetricLogBackup.self,
            from: JSONSerialization.data(withJSONObject: legacyMetricObject)
        )

        var legacyReportObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(reportDTO)) as? [String: Any]
        )
        legacyReportObject.removeValue(forKey: "recordedByHumanId")
        let legacyReportDTO = try JSONDecoder().decode(
            HumanHealthReportBackup.self,
            from: JSONSerialization.data(withJSONObject: legacyReportObject)
        )

        #expect(manager.decodeHumanHealthMetricLogSnapshot(legacyMetricDTO).recordedByHumanId == nil)
        #expect(manager.decodeHumanHealthReportSnapshot(legacyReportDTO).recordedByHumanId == nil)
    }

    @Test func petHealthRecorderAttributionRoundTripsAndLegacyBackupDefaultsToNil() throws {
        let manager = TestDataBackupManagerProjection.manager
        let symptom = SymptomLog(
            category: .skin,
            symptomName: "itch",
            severity: .moderate,
            recordedByHumanId: "symptom-recorder"
        )
        let symptomDTO = try manager.encodeSymptomLog(symptom)
        #expect(symptomDTO.recordedByHumanId == "symptom-recorder")
        #expect(try manager.decodeSymptomLogSnapshot(symptomDTO).recordedByHumanId == "symptom-recorder")

        let encodedSymptomDTO = try JSONEncoder().encode(symptomDTO)
        var legacySymptomObject = try #require(JSONSerialization.jsonObject(with: encodedSymptomDTO) as? [String: Any])
        legacySymptomObject.removeValue(forKey: "recordedByHumanId")
        let legacySymptomData = try JSONSerialization.data(withJSONObject: legacySymptomObject)
        let legacySymptomDTO = try JSONDecoder().decode(SymptomLogBackup.self, from: legacySymptomData)
        #expect(try manager.decodeSymptomLogSnapshot(legacySymptomDTO).recordedByHumanId == nil)

        let heatCycle = HeatCycleLog(
            status: .estrus,
            recordedByHumanId: "heat-recorder"
        )
        let heatDTO = manager.encodeHeatCycleLog(heatCycle)
        #expect(heatDTO.recordedByHumanId == "heat-recorder")
        #expect(manager.decodeHeatCycleLogSnapshot(heatDTO).recordedByHumanId == "heat-recorder")

        let encodedHeatDTO = try JSONEncoder().encode(heatDTO)
        var legacyHeatObject = try #require(JSONSerialization.jsonObject(with: encodedHeatDTO) as? [String: Any])
        legacyHeatObject.removeValue(forKey: "recordedByHumanId")
        let legacyHeatData = try JSONSerialization.data(withJSONObject: legacyHeatObject)
        let legacyHeatDTO = try JSONDecoder().decode(HeatCycleLogBackup.self, from: legacyHeatData)
        #expect(manager.decodeHeatCycleLogSnapshot(legacyHeatDTO).recordedByHumanId == nil)
    }

    @Test func restrictedBackupPreservesPetRelationshipAndOmitsEconomyBudgetUsageEvents() throws {
        let source = try makeInMemoryContainer()
        let sourceContext = source.mainContext
        let createdAt = Date(timeIntervalSinceReferenceDate: 7000)
        let occurredAt = Date(timeIntervalSinceReferenceDate: 7500)
        let human = Human(name: "Guan")
        human.id = try #require(UUID(uuidString: "11111111-1111-4111-8111-111111111111"))
        human.notes = "[2026-07-15] private note"
        let noteRecord = HumanNoteRecord(
            humanId: human.id,
            sequence: 0,
            date: occurredAt,
            rawEntry: human.notes,
            recordedByHumanId: human.id.uuidString
        )
        let healthMetric = HumanHealthMetricLog(
            metricKey: "private-tsh",
            unitCode: "mIU_L",
            value: 3.2,
            recordedByHumanId: human.id.uuidString,
            human: human
        )
        let healthReport = HumanHealthReport(
            humanId: human.id.uuidString,
            summary: "private summary",
            recordedByHumanId: human.id.uuidString
        )
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
        sourceContext.insert(noteRecord)
        sourceContext.insert(healthMetric)
        sourceContext.insert(healthReport)
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
        #expect(backup.humans.first?.notes.isEmpty == true)
        #expect(backup.humanNoteRecords?.isEmpty == true)
        #expect(backup.humanHealthMetricLogs?.isEmpty == true)
        #expect(backup.humanHealthReports?.isEmpty == true)

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
        #expect(try target.mainContext.fetch(FetchDescriptor<HumanNoteRecord>()).isEmpty)
        #expect(try target.mainContext.fetch(FetchDescriptor<HumanHealthMetricLog>()).isEmpty)
        #expect(try target.mainContext.fetch(FetchDescriptor<HumanHealthReport>()).isEmpty)
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

    @Test func v32PresenceFactsRoundTripIdempotentlyWhileContactsStayLocal() throws {
        let sourceDefaultsName = "DataBackupPresenceSource.\(UUID().uuidString)"
        let targetDefaultsName = "DataBackupPresenceTarget.\(UUID().uuidString)"
        let sourceDefaults = try #require(UserDefaults(suiteName: sourceDefaultsName))
        let targetDefaults = try #require(UserDefaults(suiteName: targetDefaultsName))
        defer {
            sourceDefaults.removePersistentDomain(forName: sourceDefaultsName)
            targetDefaults.removePersistentDomain(forName: targetDefaultsName)
        }
        let sourceReminderConfiguration = PresenceReminderConfiguration(
            isEnabled: true,
            schedules: [.init(hour: 19, minute: 45)],
            gracePeriodMinutes: 30,
            sendsSecondLocalReminder: true,
            messageTemplate: "SOURCE-LOCAL-ONLY-MESSAGE"
        )
        PresenceReminderConfigurationStore(defaults: sourceDefaults).save(sourceReminderConfiguration)
        sourceDefaults.set(AppExperienceMode.zen.rawValue, forKey: AppExperienceMode.storageKey)
        sourceDefaults.set(
            "10000000-0000-4000-8000-000000000099",
            forKey: AppExperienceMode.zenOwnerHumanIDKey
        )

        let source = try makeInMemoryContainer()
        let context = source.mainContext
        let ownerID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
        let checkInID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000002"))
        let periodID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000003"))
        let receiptID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000004"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-18T18:00:00Z"))
        let human = Human(name: "Owner")
        human.id = ownerID
        let ownerSubject = PresenceSubjectRef(kind: .human, id: ownerID)
        let checkIn = PresenceCheckIn(
            id: checkInID,
            uniqueKey: PresenceCheckInCommandService.checkInKey(
                subject: ownerSubject,
                dayKey: "2026-07-18"
            ),
            subject: ownerSubject,
            ownerHumanId: ownerID,
            isOwner: true,
            dayKey: "2026-07-18",
            timeZoneIdentifier: "Europe/Berlin",
            checkedInAt: now,
            source: .card,
            status: .great,
            operatorHumanId: ownerID
        )
        let period = PresenceParticipationPeriod(
            id: periodID,
            periodKey: "presence-period:test",
            ownerHumanId: ownerID,
            startedAt: now,
            startedDayKey: "2026-07-18",
            startedTimeZoneIdentifier: "Europe/Berlin",
            source: .settings
        )
        let receipt = PresenceRewardReceipt(
            id: receiptID,
            receiptKey: PresenceCheckInCommandService.ownerDailyReceiptKey(dayKey: "2026-07-18"),
            ownerHumanId: ownerID,
            rewardKind: .ownerDaily,
            dayKey: "2026-07-18",
            requestedAmount: 1,
            awardedAmount: 1,
            walletTransactionKey: "presence-wallet-test",
            relatedCheckInId: checkInID,
            awardedAt: now
        )
        let contact = SafetyContact(name: "Secret Contact", phoneNumber: "+49 123 456")
        context.insert(human)
        context.insert(checkIn)
        context.insert(period)
        context.insert(receipt)
        context.insert(contact)
        try context.save()

        let manager = DataBackupManager(defaults: sourceDefaults)
        let backup = try manager.buildBackup(context: context)
        #expect(backup.schemaVersion == 33)
        #expect(backup.presenceCheckIns?.count == 1)
        #expect(backup.presenceParticipationPeriods?.count == 1)
        #expect(backup.presenceRewardReceipts?.count == 1)
        let manifest = try manager.encode(backup)
        let manifestText = try #require(String(data: manifest, encoding: .utf8))
        #expect(!manifestText.contains("Secret Contact"))
        #expect(!manifestText.contains("+49 123 456"))
        #expect(!manifestText.contains("SOURCE-LOCAL-ONLY-MESSAGE"))
        #expect(!manifestText.contains(PresenceReminderConfigurationStore.storageKey))

        let decoded = try JSONDecoder().decode(OhanaBackup.self, from: manifest)
        #expect(decoded.schemaVersion == 33)
        #expect(decoded.presenceCheckIns == backup.presenceCheckIns)
        #expect(decoded.presenceParticipationPeriods == backup.presenceParticipationPeriods)
        #expect(decoded.presenceRewardReceipts == backup.presenceRewardReceipts)

        var malformed = decoded
        malformed.presenceCheckIns?[0].uniqueKey = "forged-presence-natural-key"
        let malformedTarget = try makeInMemoryContainer()
        do {
            try DataBackupManager(defaults: targetDefaults).applyBackup(
                malformed,
                context: malformedTarget.mainContext,
                projectionManager: nil,
                schedulePlantNotifications: false
            )
            Issue.record("Restore accepted a PresenceCheckIn whose natural key did not match its subject and day.")
        } catch let BackupError.invalidRestoreData(category) {
            #expect(category == .identity)
        } catch {
            Issue.record("Restore rejected malformed Presence data with an unexpected error: \(error)")
        }
        #expect(try malformedTarget.mainContext.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)

        let targetReminderConfiguration = PresenceReminderConfiguration(
            isEnabled: false,
            schedules: [.init(hour: 8, minute: 15)],
            gracePeriodMinutes: nil,
            sendsSecondLocalReminder: false,
            messageTemplate: "TARGET-DEVICE-SETTING"
        )
        let targetReminderStore = PresenceReminderConfigurationStore(defaults: targetDefaults)
        targetReminderStore.save(targetReminderConfiguration)
        targetDefaults.set(AppExperienceMode.standard.rawValue, forKey: AppExperienceMode.storageKey)
        let restoreManager = DataBackupManager(defaults: targetDefaults)

        let target = try makeInMemoryContainer()
        for _ in 0 ..< 2 {
            try restoreManager.applyBackup(
                decoded,
                context: target.mainContext,
                projectionManager: nil,
                schedulePlantNotifications: false
            )
        }

        #expect(try target.mainContext.fetch(FetchDescriptor<PresenceCheckIn>()).count == 1)
        let restoredPeriods = try target.mainContext.fetch(FetchDescriptor<PresenceParticipationPeriod>())
        #expect(restoredPeriods.count == 1)
        #expect(restoredPeriods.first?.endedAt != nil)
        #expect(try target.mainContext.fetch(FetchDescriptor<PresenceRewardReceipt>()).count == 1)
        #expect(try target.mainContext.fetch(FetchDescriptor<SafetyContact>()).isEmpty)
        let restoredLedger = try target.mainContext.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(!restoredLedger.contains {
            $0.sourceModelName == "PresenceRewardReceipt" || $0.transactionKey == "presence-wallet-test"
        })
        #expect(targetReminderStore.load() == targetReminderConfiguration)
        #expect(targetDefaults.string(forKey: AppExperienceMode.storageKey) == AppExperienceMode.standard.rawValue)
    }

    @Test func v31ManifestWithoutPresenceFieldsStillDecodes() throws {
        let defaultsName = "DataBackupV31Presence.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let manager = DataBackupManager(defaults: defaults)
        let source = try makeInMemoryContainer()
        let backup = try manager.buildBackup(context: source.mainContext)
        let data = try manager.encode(backup)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = 31
        object.removeValue(forKey: "presenceCheckIns")
        object.removeValue(forKey: "presenceParticipationPeriods")
        object.removeValue(forKey: "presenceRewardReceipts")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(OhanaBackup.self, from: legacyData)
        #expect(decoded.schemaVersion == 31)
        #expect(decoded.presenceCheckIns == nil)
        #expect(decoded.presenceParticipationPeriods == nil)
        #expect(decoded.presenceRewardReceipts == nil)

        let target = try makeInMemoryContainer()
        try manager.applyBackup(
            decoded,
            context: target.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false
        )
        #expect(try target.mainContext.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
        #expect(try target.mainContext.fetchCount(FetchDescriptor<PresenceParticipationPeriod>()) == 0)
        #expect(try target.mainContext.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 0)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, configurations: [config])
    }

    private func backupManifestData(from packageURL: URL) throws -> Data {
        try Data(contentsOf: packageURL.appendingPathComponent(DataBackupManager.manifestFileName, isDirectory: false))
    }
}
