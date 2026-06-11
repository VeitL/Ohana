//
//  CloudSyncRecordApplier.swift
//  Ohana
//
//  Applies fetched CloudKit records into the local SwiftData store.
//

import CloudKit
import Foundation
import SwiftData

nonisolated enum CloudSyncRecordApplyResult: Equatable, Sendable {
    case inserted(entityName: String, localRecordId: String)
    case updated(entityName: String, localRecordId: String)
    case deleted(entityName: String, localRecordId: String)
    case skippedStale(entityName: String, localRecordId: String)
    case skippedUnsupported(entityName: String)
}

nonisolated struct CloudSyncRecordApplySummary: Equatable, Sendable {
    static let empty = CloudSyncRecordApplySummary()

    var inserted = 0
    var updated = 0
    var deleted = 0
    var skippedStale = 0
    var skippedUnsupported = 0
    var failed = 0

    var hasMutations: Bool {
        inserted > 0 || updated > 0 || deleted > 0
    }

    mutating func record(_ result: CloudSyncRecordApplyResult) {
        switch result {
        case .inserted:
            inserted += 1
        case .updated:
            updated += 1
        case .deleted:
            deleted += 1
        case .skippedStale:
            skippedStale += 1
        case .skippedUnsupported:
            skippedUnsupported += 1
        }
    }
}

nonisolated enum CloudSyncRecordApplyError: LocalizedError, Equatable {
    case missingLocalRecordId(recordName: String)
    case invalidLocalRecordId(entityName: String, localRecordId: String)

    var errorDescription: String? {
        switch self {
        case let .missingLocalRecordId(recordName):
            "Cloud sync record \(recordName) is missing a local record id."
        case let .invalidLocalRecordId(entityName, localRecordId):
            "Cloud sync \(entityName) record has an invalid local record id: \(localRecordId)."
        }
    }
}

nonisolated enum CloudSyncRecordApplier {
    @discardableResult
    static func apply(_ record: CKRecord, context: ModelContext) throws -> CloudSyncRecordApplyResult {
        let metadata = try RemoteMetadata(record: record)
        guard let descriptor = CloudSyncEntityRegistry.descriptor(for: metadata.entityName),
              descriptor.uploadsToCloudKit else {
            return .skippedUnsupported(entityName: metadata.entityName)
        }
        guard supportsApply(for: descriptor.entityName) else {
            return .skippedUnsupported(entityName: descriptor.entityName)
        }
        if let existingState = try CloudSyncMetadataService.state(recordKey: metadata.recordKey, context: context),
           existingState.lastModifiedAt > metadata.lastModifiedAt {
            return .skippedStale(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        if metadata.isDeleted {
            try deleteLocalModel(metadata: metadata, context: context)
            let state = try upsertState(metadata: metadata, record: record, context: context)
            state.isDeleted = true
            state.deletedAt = metadata.deletedAt ?? metadata.lastModifiedAt
            state.deletedByHumanId = metadata.deletedByHumanId
            CloudSyncMetadataService.markSynced(
                state,
                ckRecordName: record.recordID.recordName,
                ckChangeTag: record.recordChangeTag ?? "",
                ckZoneName: record.recordID.zoneID.zoneName,
                syncedAt: Date()
            )
            return .deleted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let result = try applyLiveRecord(record, metadata: metadata, descriptor: descriptor, context: context)
        let state = try upsertState(metadata: metadata, record: record, context: context)
        state.isDeleted = false
        state.deletedAt = nil
        state.deletedByHumanId = ""
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag ?? "",
            ckZoneName: record.recordID.zoneID.zoneName,
            syncedAt: Date()
        )
        return result
    }

    private static func supportsApply(for entityName: String) -> Bool {
        switch CloudSyncRecordState.normalizedEntityName(entityName) {
        case String(describing: Household.self),
             String(describing: Pet.self),
             String(describing: Human.self),
             String(describing: PetCareLog.self),
             String(describing: PetPottyLog.self),
             String(describing: PetHygieneLog.self),
             String(describing: PetHealthLog.self),
             String(describing: PetWalkLog.self),
             String(describing: PetExpenseLog.self),
             String(describing: PetWeightLog.self),
             String(describing: CoconutLedgerEntry.self):
            true
        default:
            false
        }
    }

    private static func applyLiveRecord(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        descriptor: CloudSyncEntityDescriptor,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        switch descriptor.entityName {
        case String(describing: Household.self):
            try applyHousehold(record, metadata: metadata, context: context)
        case String(describing: Pet.self):
            try applyPet(record, metadata: metadata, context: context)
        case String(describing: Human.self):
            try applyHuman(record, metadata: metadata, context: context)
        case String(describing: PetCareLog.self):
            try applyPetCareLog(record, metadata: metadata, context: context)
        case String(describing: PetPottyLog.self):
            try applyPetPottyLog(record, metadata: metadata, context: context)
        case String(describing: PetHygieneLog.self):
            try applyPetHygieneLog(record, metadata: metadata, context: context)
        case String(describing: PetHealthLog.self):
            try applyPetHealthLog(record, metadata: metadata, context: context)
        case String(describing: PetWalkLog.self):
            try applyPetWalkLog(record, metadata: metadata, context: context)
        case String(describing: PetExpenseLog.self):
            try applyPetExpenseLog(record, metadata: metadata, context: context)
        case String(describing: PetWeightLog.self):
            try applyPetWeightLog(record, metadata: metadata, context: context)
        case String(describing: CoconutLedgerEntry.self):
            try applyCoconutLedgerEntry(record, metadata: metadata, context: context)
        default:
            .skippedUnsupported(entityName: descriptor.entityName)
        }
    }

    private static func applyHousehold(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if let household = try fetchHousehold(id: metadata.localRecordUUID, context: context) {
            if let name = record.string(for: "name") {
                household.name = name
            }
            if let createdAt = record.date(for: "createdAt") {
                household.createdAt = createdAt
            }
            if let totalProsperity = record.int(for: "totalProsperity") {
                household.totalProsperity = max(household.totalProsperity, totalProsperity)
            }
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let household = Household(name: record.string(for: "name") ?? "")
        household.id = metadata.localRecordUUID
        household.createdAt = record.date(for: "createdAt") ?? metadata.lastModifiedAt
        household.totalProsperity = max(0, record.int(for: "totalProsperity") ?? 0)
        context.insert(household)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPet(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let pet: Pet
        let result: CloudSyncRecordApplyResult
        if let existing = try fetchPet(id: metadata.localRecordUUID, context: context) {
            pet = existing
            result = .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        } else {
            pet = Pet(name: record.string(for: "name") ?? "")
            pet.id = metadata.localRecordUUID
            context.insert(pet)
            result = .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        pet.name = record.string(for: "name") ?? pet.name
        pet.species = record.string(for: "species") ?? pet.species
        pet.breed = record.string(for: "breed") ?? pet.breed
        pet.birthday = record.date(for: "birthday")
        pet.gender = record.string(for: "gender") ?? pet.gender
        pet.isNeutered = record.bool(for: "isNeutered") ?? pet.isNeutered
        pet.avatarEmoji = record.string(for: "avatarEmoji") ?? pet.avatarEmoji
        pet.avatarImageData = record.assetData(for: "avatarImageData")
        pet.microchipID = record.string(for: "microchipID") ?? pet.microchipID
        pet.vetContact = record.string(for: "vetContact") ?? pet.vetContact
        pet.vetClinicName = record.string(for: "vetClinicName") ?? pet.vetClinicName
        pet.vetDoctorName = record.string(for: "vetDoctorName") ?? pet.vetDoctorName
        pet.vetAddress = record.string(for: "vetAddress") ?? pet.vetAddress
        pet.allergies = record.string(for: "allergies") ?? pet.allergies
        pet.passportNumber = record.string(for: "passportNumber") ?? pet.passportNumber
        pet.passportExpiryDate = record.date(for: "passportExpiryDate")
        pet.formerName = record.string(for: "formerName") ?? pet.formerName
        pet.lineageInfo = record.string(for: "lineageInfo") ?? pet.lineageInfo
        pet.themeColorHex = record.string(for: "themeColorHex") ?? pet.themeColorHex
        pet.homeDate = record.date(for: "homeDate")
        pet.birthCountry = record.string(for: "birthCountry") ?? pet.birthCountry
        pet.birthCity = record.string(for: "birthCity") ?? pet.birthCity
        pet.foodBrand = record.string(for: "foodBrand") ?? pet.foodBrand
        pet.restockDate = record.date(for: "restockDate")
        pet.restockWeight = record.double(for: "restockWeight") ?? pet.restockWeight
        pet.dailyPortionGrams = record.double(for: "dailyPortionGrams") ?? pet.dailyPortionGrams
        pet.mainFoodKindRaw = record.string(for: "mainFoodKindRaw") ?? pet.mainFoodKindRaw
        pet.foodPrice = record.double(for: "foodPrice") ?? pet.foodPrice
        pet.isShared = record.bool(for: "isShared") ?? pet.isShared
        pet.ckRecordName = record.recordID.recordName
        pet.createdAt = record.date(for: "createdAt") ?? pet.createdAt
        pet.notes = record.string(for: "notes") ?? pet.notes
        pet.coatColor = record.string(for: "coatColor") ?? pet.coatColor
        pet.eyeColor = record.string(for: "eyeColor") ?? pet.eyeColor
        pet.currentStreak = record.int(for: "currentStreak") ?? pet.currentStreak
        pet.lastCheckInDate = record.date(for: "lastCheckInDate")
        pet.foodTrackingModeRaw = record.string(for: "foodTrackingModeRaw") ?? pet.foodTrackingModeRaw
        pet.casualOpenDate = record.date(for: "casualOpenDate")
        pet.casualDurationDays = record.int(for: "casualDurationDays") ?? pet.casualDurationDays
        pet.foodReminderEnabled = record.bool(for: "foodReminderEnabled") ?? pet.foodReminderEnabled
        pet.foodReminderAdvanceDays = record.int(for: "foodReminderAdvanceDays") ?? pet.foodReminderAdvanceDays
        pet.passedAwayDate = record.date(for: "passedAwayDate")
        pet.cardStyleRaw = record.string(for: "cardStyleRaw") ?? pet.cardStyleRaw
        pet.cardPopoutImageData = record.assetData(for: "cardPopoutImageData")
        pet.cardPopoutSourceRaw = record.string(for: "cardPopoutSourceRaw")
        pet.weeklyWalkGoalKm = record.double(for: "weeklyWalkGoalKm") ?? pet.weeklyWalkGoalKm
        pet.personalityTagsRaw = record.string(for: "personalityTagsRaw") ?? pet.personalityTagsRaw
        return result
    }

    private static func applyHuman(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let human: Human
        let result: CloudSyncRecordApplyResult
        if let existing = try fetchHuman(id: metadata.localRecordUUID, context: context) {
            human = existing
            result = .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        } else {
            human = Human(name: record.string(for: "name") ?? "")
            human.id = metadata.localRecordUUID
            context.insert(human)
            result = .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        human.name = record.string(for: "name") ?? human.name
        human.birthday = record.date(for: "birthday")
        human.bloodType = record.string(for: "bloodType") ?? human.bloodType
        human.avatarEmoji = record.string(for: "avatarEmoji") ?? human.avatarEmoji
        human.avatarImageData = record.assetData(for: "avatarImageData")
        human.role = record.string(for: "role") ?? human.role
        human.notes = record.string(for: "notes") ?? human.notes
        human.createdAt = record.date(for: "createdAt") ?? human.createdAt
        human.nationality = record.string(for: "nationality") ?? human.nationality
        human.city = record.string(for: "city") ?? human.city
        human.shouldShowOnHome = record.bool(for: "shouldShowOnHome") ?? human.shouldShowOnHome
        human.themeColorHex = record.string(for: "themeColorHex") ?? human.themeColorHex
        human.genderIdentityRaw = record.string(for: "genderIdentityRaw")
        human.privateFieldsRaw = record.string(for: "privateFieldsRaw") ?? human.privateFieldsRaw
        human.heightCm = record.double(for: "heightCm") ?? human.heightCm
        human.mbti = record.string(for: "mbti") ?? human.mbti
        human.passedAwayDate = record.date(for: "passedAwayDate")
        return result
    }

    private static func applyPetCareLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetCareLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let petId = record.string(for: "petId").flatMap(UUID.init(uuidString:))
        let pet: Pet? = if let petId {
            try fetchPet(id: petId, context: context)
        } else {
            nil
        }
        let log = PetCareLog(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            type: CareType(rawValue: record.string(for: "type") ?? "") ?? .feeding,
            amountGrams: record.double(for: "amountGrams") ?? 0,
            amountMl: record.double(for: "amountMl") ?? 0,
            note: record.string(for: "note") ?? "",
            foodKind: FeedFoodKind(rawValue: record.string(for: "foodKindRaw") ?? "") ?? .dry,
            treatKind: record.string(for: "treatKindRaw").flatMap(FeedTreatKind.init(rawValue:)),
            autoFeedDedupKey: record.string(for: "autoFeedDedupKey") ?? "",
            sharedSessionId: record.string(for: "sharedSessionId") ?? "",
            pet: pet,
            executorId: record.string(for: "executorId")
        )
        log.id = metadata.localRecordUUID
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPetPottyLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetPottyLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let pet = try petReference(from: record, context: context)
        let log = PetPottyLog(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            type: PottyType(rawValue: record.string(for: "type") ?? "") ?? .perfectPoop,
            pet: pet,
            executorId: record.string(for: "executorId"),
            latitude: record.double(for: "latitude"),
            longitude: record.double(for: "longitude"),
            locationAccuracyMeters: record.double(for: "locationAccuracyMeters"),
            walkLogId: record.string(for: "walkLogId"),
            sharedSessionId: record.string(for: "sharedSessionId") ?? ""
        )
        log.id = metadata.localRecordUUID
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPetHygieneLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetHygieneLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let pet = try petReference(from: record, context: context)
        let log = PetHygieneLog(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            type: HygieneType(rawValue: record.string(for: "type") ?? "") ?? .bath,
            pet: pet,
            executorId: record.string(for: "executorId")
        )
        log.id = metadata.localRecordUUID
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPetHealthLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetHealthLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let pet = try petReference(from: record, context: context)
        let log = PetHealthLog(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            type: HealthLogType(rawValue: record.string(for: "type") ?? "") ?? .general,
            note: record.string(for: "note") ?? "",
            pet: pet,
            executorId: record.string(for: "executorId")
        )
        log.id = metadata.localRecordUUID
        log.vetName = record.string(for: "vetName") ?? ""
        log.cost = record.double(for: "cost") ?? 0
        log.expirationDate = record.date(for: "expirationDate")
        log.nextCheckupDate = record.date(for: "nextCheckupDate")
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPetWalkLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetWalkLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let pet = try petReference(from: record, context: context)
        let log = PetWalkLog(
            startDate: record.date(for: "startDate") ?? metadata.lastModifiedAt,
            pet: pet,
            executorId: record.string(for: "executorId"),
            sharedSessionId: record.string(for: "sharedSessionId") ?? ""
        )
        log.id = metadata.localRecordUUID
        log.endDate = record.date(for: "endDate")
        log.distanceMeters = record.double(for: "distanceMeters") ?? 0
        log.coconutsEarned = record.int(for: "coconutsEarned") ?? 0
        log.mapSnapshotData = record.assetData(for: "mapSnapshotData")
        log.routeLocationsData = record.assetData(for: "routeLocationsData")
        log.behaviorNotes = record.string(for: "behaviorNotes")
        log.moodRating = record.int(for: "moodRating") ?? 0
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPetExpenseLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetExpenseLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let pet = try petReference(from: record, context: context)
        let log = PetExpenseLog(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            amount: record.double(for: "amount") ?? 0,
            category: ExpenseCategory(rawValue: record.string(for: "category") ?? "") ?? .other,
            note: record.string(for: "note") ?? "",
            pet: pet,
            executorId: record.string(for: "executorId"),
            sharedSessionId: record.string(for: "sharedSessionId") ?? ""
        )
        log.id = metadata.localRecordUUID
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyPetWeightLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchPetWeightLog(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let pet = try petReference(from: record, context: context)
        let log = PetWeightLog(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            weight: record.double(for: "weight") ?? 0,
            weightUnit: record.string(for: "weightUnit") ?? "kg",
            bcsScore: record.int(for: "bcsScore") ?? 0,
            pet: pet,
            executorId: record.string(for: "executorId")
        )
        log.id = metadata.localRecordUUID
        context.insert(log)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyCoconutLedgerEntry(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchCoconutLedgerEntry(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let ownerKindRaw = record.string(for: "ownerKindRaw") ?? CoconutWalletOwnerKind.system.rawValue
        let entryKindRaw = record.string(for: "entryKindRaw") ?? CoconutWalletEntryKind.adjustment.rawValue
        let sourceRaw = record.string(for: "sourceRaw") ?? CoconutWalletSource.service.rawValue
        let subjectKindRaw = record.string(for: "subjectKindRaw") ?? CareLedgerSubjectKind.system.rawValue
        let entry = CoconutLedgerEntry(
            id: metadata.localRecordUUID,
            transactionKey: record.string(for: "transactionKey") ?? metadata.recordKey,
            accountKey: record.string(for: "accountKey") ?? CoconutAccountKey.system(),
            ownerKind: CoconutWalletOwnerKind(rawValue: ownerKindRaw) ?? .system,
            ownerId: record.string(for: "ownerId") ?? "",
            ownerName: record.string(for: "ownerName") ?? "",
            delta: record.int(for: "delta") ?? 0,
            balanceBefore: record.int(for: "balanceBefore") ?? 0,
            balanceAfter: record.int(for: "balanceAfter") ?? 0,
            affectsBalance: record.bool(for: "affectsBalance") ?? true,
            entryKind: CoconutWalletEntryKind(rawValue: entryKindRaw) ?? .adjustment,
            source: CoconutWalletSource(rawValue: sourceRaw) ?? .service,
            title: record.string(for: "title") ?? "",
            emoji: record.string(for: "emoji") ?? "",
            actorId: record.string(for: "actorId"),
            actorName: record.string(for: "actorName"),
            subjectKind: CareLedgerSubjectKind(rawValue: subjectKindRaw) ?? .system,
            subjectId: record.string(for: "subjectId"),
            sourceModelName: record.string(for: "sourceModelName") ?? "",
            sourceModelId: record.string(for: "sourceModelId") ?? "",
            careLedgerEventId: record.string(for: "careLedgerEventId"),
            metadataJSON: record.string(for: "metadataJSON") ?? "",
            occurredAt: record.date(for: "occurredAt") ?? metadata.lastModifiedAt,
            createdAt: record.date(for: "createdAt") ?? metadata.lastModifiedAt
        )
        entry.ownerKindRaw = ownerKindRaw
        entry.entryKindRaw = entryKindRaw
        entry.sourceRaw = sourceRaw
        entry.subjectKindRaw = subjectKindRaw
        context.insert(entry)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func upsertState(
        metadata: RemoteMetadata,
        record: CKRecord,
        context: ModelContext
    ) throws -> CloudSyncRecordState {
        let state: CloudSyncRecordState
        if let existing = try CloudSyncMetadataService.state(recordKey: metadata.recordKey, context: context) {
            state = existing
            state.householdId = metadata.householdId
            state.conflictPolicy = metadata.conflictPolicy
            state.lastModifiedAt = metadata.lastModifiedAt
        } else {
            state = CloudSyncRecordState(
                entityName: metadata.entityName,
                localRecordId: metadata.localRecordUUID,
                householdId: metadata.householdUUID,
                ckZoneName: record.recordID.zoneID.zoneName,
                ckRecordName: record.recordID.recordName,
                ckChangeTag: record.recordChangeTag ?? "",
                conflictPolicy: metadata.conflictPolicy,
                isDeleted: metadata.isDeleted,
                deletedAt: metadata.deletedAt,
                deletedByHumanId: metadata.deletedByHumanUUID,
                hasPendingLocalChanges: false,
                lastModifiedAt: metadata.lastModifiedAt,
                lastSyncedAt: Date(),
                createdAt: metadata.lastModifiedAt,
                updatedAt: Date()
            )
            context.insert(state)
        }
        return state
    }

    private static func deleteLocalModel(metadata: RemoteMetadata, context: ModelContext) throws {
        switch metadata.entityName {
        case String(describing: Household.self):
            if let model = try fetchHousehold(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: Pet.self):
            if let model = try fetchPet(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: Human.self):
            if let model = try fetchHuman(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetCareLog.self):
            if let model = try fetchPetCareLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetPottyLog.self):
            if let model = try fetchPetPottyLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetHygieneLog.self):
            if let model = try fetchPetHygieneLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetHealthLog.self):
            if let model = try fetchPetHealthLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetWalkLog.self):
            if let model = try fetchPetWalkLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetExpenseLog.self):
            if let model = try fetchPetExpenseLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetWeightLog.self):
            if let model = try fetchPetWeightLog(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: CoconutLedgerEntry.self):
            if let model = try fetchCoconutLedgerEntry(id: metadata.localRecordUUID, context: context) {
                context.delete(model)
            }
        default:
            break
        }
    }

    private static func fetchHousehold(id: UUID, context: ModelContext) throws -> Household? {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetCareLog(id: UUID, context: ModelContext) throws -> PetCareLog? {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetPottyLog(id: UUID, context: ModelContext) throws -> PetPottyLog? {
        var descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetHygieneLog(id: UUID, context: ModelContext) throws -> PetHygieneLog? {
        var descriptor = FetchDescriptor<PetHygieneLog>(
            predicate: #Predicate<PetHygieneLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetHealthLog(id: UUID, context: ModelContext) throws -> PetHealthLog? {
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetWalkLog(id: UUID, context: ModelContext) throws -> PetWalkLog? {
        var descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetExpenseLog(id: UUID, context: ModelContext) throws -> PetExpenseLog? {
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetWeightLog(id: UUID, context: ModelContext) throws -> PetWeightLog? {
        var descriptor = FetchDescriptor<PetWeightLog>(
            predicate: #Predicate<PetWeightLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchCoconutLedgerEntry(id: UUID, context: ModelContext) throws -> CoconutLedgerEntry? {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func petReference(from record: CKRecord, context: ModelContext) throws -> Pet? {
        guard let petId = record.string(for: "petId").flatMap(UUID.init(uuidString:)) else {
            return nil
        }
        return try fetchPet(id: petId, context: context)
    }
}

private struct RemoteMetadata {
    let entityName: String
    let recordKey: String
    let localRecordId: String
    let localRecordUUID: UUID
    let householdId: String
    let householdUUID: UUID?
    let isDeleted: Bool
    let deletedAt: Date?
    let deletedByHumanId: String
    let deletedByHumanUUID: UUID?
    let lastModifiedAt: Date
    let conflictPolicy: CloudSyncConflictPolicy

    init(record: CKRecord) throws {
        entityName = CloudSyncRecordState.normalizedEntityName(
            record.string(for: CloudSyncRecordFieldKey.entityName) ?? record.recordType
        )
        let rawLocalRecordId = record.string(for: CloudSyncRecordFieldKey.localRecordId)
            ?? Self.localRecordIdFromRecordName(record.recordID.recordName, entityName: entityName)
        guard let rawLocalRecordId else {
            throw CloudSyncRecordApplyError.missingLocalRecordId(recordName: record.recordID.recordName)
        }
        let normalizedLocalRecordId = CloudSyncRecordState.normalizedRecordId(rawLocalRecordId)
        guard let localRecordUUID = UUID(uuidString: normalizedLocalRecordId) else {
            throw CloudSyncRecordApplyError.invalidLocalRecordId(
                entityName: entityName,
                localRecordId: normalizedLocalRecordId
            )
        }

        localRecordId = normalizedLocalRecordId
        self.localRecordUUID = localRecordUUID
        recordKey = record.string(for: CloudSyncRecordFieldKey.recordKey)
            ?? CloudSyncRecordState.recordKey(entityName: entityName, localRecordId: normalizedLocalRecordId)

        let rawHouseholdId = record.string(for: CloudSyncRecordFieldKey.householdId)
            ?? Self.householdIdFromZoneName(record.recordID.zoneID.zoneName)
            ?? (entityName == String(describing: Household.self) ? normalizedLocalRecordId : "")
        householdId = CloudSyncRecordState.normalizedRecordId(rawHouseholdId)
        householdUUID = UUID(uuidString: householdId)
        isDeleted = record.bool(for: CloudSyncRecordFieldKey.isDeleted) ?? false
        deletedAt = record.date(for: CloudSyncRecordFieldKey.deletedAt)
        deletedByHumanId = record.string(for: CloudSyncRecordFieldKey.deletedByHumanId) ?? ""
        deletedByHumanUUID = UUID(uuidString: deletedByHumanId)
        lastModifiedAt = record.date(for: CloudSyncRecordFieldKey.lastModifiedAt)
            ?? record.modificationDate
            ?? Date(timeIntervalSinceReferenceDate: 0)
        conflictPolicy = record.string(for: CloudSyncRecordFieldKey.conflictPolicy)
            .flatMap(CloudSyncConflictPolicy.init(rawValue:))
            ?? CloudSyncMergePolicy.defaultConflictPolicy(for: entityName)
    }

    private static func localRecordIdFromRecordName(_ recordName: String, entityName: String) -> String? {
        let prefix = "\(entityName)_"
        guard recordName.hasPrefix(prefix) else { return nil }
        return String(recordName.dropFirst(prefix.count))
    }

    private static func householdIdFromZoneName(_ zoneName: String) -> String? {
        let prefix = "household-"
        guard zoneName.hasPrefix(prefix) else { return nil }
        return String(zoneName.dropFirst(prefix.count))
    }
}

private extension CKRecord {
    func string(for key: String) -> String? {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] as? NSString {
            return value as String
        }
        return nil
    }

    func int(for key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        return nil
    }

    func double(for key: String) -> Double? {
        if let value = self[key] as? Double {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    func bool(for key: String) -> Bool? {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.boolValue
        }
        return nil
    }

    func date(for key: String) -> Date? {
        if let value = self[key] as? Date {
            return value
        }
        if let value = self[key] as? NSDate {
            return value as Date
        }
        return nil
    }

    func assetData(for key: String) -> Data? {
        guard let asset = self[key] as? CKAsset,
              let fileURL = asset.fileURL else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }
}
