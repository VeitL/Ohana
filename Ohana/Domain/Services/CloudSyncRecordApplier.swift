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
            state.isDeletionTombstone = true
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
        state.isDeletionTombstone = false
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

    @discardableResult
    static func applyHardDeletedRecord(
        recordID: CKRecord.ID,
        recordType: CKRecord.RecordType,
        deletedAt: Date = Date(),
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let entityName = CloudSyncRecordState.normalizedEntityName(recordType)
        guard let descriptor = CloudSyncEntityRegistry.descriptor(for: entityName),
              descriptor.uploadsToCloudKit else {
            return .skippedUnsupported(entityName: entityName)
        }
        guard supportsApply(for: descriptor.entityName) else {
            return .skippedUnsupported(entityName: descriptor.entityName)
        }
        let matchedState = try CloudSyncMetadataService.state(
            entityName: descriptor.entityName,
            ckRecordName: recordID.recordName,
            ckZoneName: recordID.zoneID.zoneName,
            context: context
        )
        let parsedLocalRecordId = CloudSyncRecordIdentityParser.localRecordIdFromRecordName(
            recordID.recordName,
            entityName: descriptor.entityName
        )
        guard let rawLocalRecordId = parsedLocalRecordId ?? matchedState?.localRecordId else {
            throw CloudSyncRecordApplyError.missingLocalRecordId(recordName: recordID.recordName)
        }
        let localRecordId = CloudSyncRecordState.normalizedRecordId(rawLocalRecordId)
        guard let localRecordUUID = UUID(uuidString: localRecordId) else {
            throw CloudSyncRecordApplyError.invalidLocalRecordId(
                entityName: descriptor.entityName,
                localRecordId: localRecordId
            )
        }

        let matchedHouseholdId = matchedState?.householdId.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawHouseholdId = CloudSyncRecordIdentityParser.householdIdFromZoneName(recordID.zoneID.zoneName)
            ?? (matchedHouseholdId?.isEmpty == false ? matchedHouseholdId : nil)
            ?? (descriptor.entityName == String(describing: Household.self) ? localRecordId : "")
        let householdId = CloudSyncRecordState.normalizedRecordId(rawHouseholdId)
        let householdUUID = UUID(uuidString: householdId)
        let recordKey = CloudSyncRecordState.recordKey(
            entityName: descriptor.entityName,
            localRecordId: localRecordId
        )

        try deleteLocalModel(
            entityName: descriptor.entityName,
            localRecordUUID: localRecordUUID,
            context: context
        )
        let state: CloudSyncRecordState
        let existingState: CloudSyncRecordState? = if let matchedState {
            matchedState
        } else {
            try CloudSyncMetadataService.state(recordKey: recordKey, context: context)
        }
        if let existing = existingState {
            state = existing
            state.householdId = householdId
            state.conflictPolicy = descriptor.defaultConflictPolicy
        } else {
            state = CloudSyncRecordState(
                entityName: descriptor.entityName,
                localRecordId: localRecordUUID,
                householdId: householdUUID,
                ckZoneName: recordID.zoneID.zoneName,
                ckRecordName: recordID.recordName,
                ckChangeTag: "",
                conflictPolicy: descriptor.defaultConflictPolicy,
                isDeleted: true,
                deletedAt: deletedAt,
                hasPendingLocalChanges: false,
                lastModifiedAt: deletedAt,
                lastSyncedAt: Date(),
                createdAt: deletedAt,
                updatedAt: Date()
            )
            context.insert(state)
        }
        state.ckRecordName = recordID.recordName
        state.ckZoneName = recordID.zoneID.zoneName
        state.ckChangeTag = ""
        state.isDeleted = true
        state.isDeletionTombstone = true
        state.deletedAt = deletedAt
        state.deletedByHumanId = ""
        state.hasPendingLocalChanges = false
        state.lastModifiedAt = deletedAt
        state.lastSyncedAt = Date()
        state.updatedAt = Date()
        return .deleted(entityName: descriptor.entityName, localRecordId: localRecordId)
    }

    private static func supportsApply(for entityName: String) -> Bool {
        CloudSyncEntityRegistry.supportsUploadPipeline(for: entityName)
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
        case String(describing: SharedCareSession.self):
            try applySharedCareSession(record, metadata: metadata, context: context)
        case String(describing: CareLedgerEvent.self):
            try applyCareLedgerEvent(record, metadata: metadata, context: context)
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
            executorIds: SharedCareParticipantIDs.decode(
                record.string(for: "executorIdsRaw") ?? "",
                fallback: record.string(for: "executorId")
            ),
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

    private static func applySharedCareSession(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        if try fetchSharedCareSession(id: metadata.localRecordUUID, context: context) != nil {
            return .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let targetPetIds = (record.string(for: "targetPetIdsRaw") ?? "")
            .split(separator: "|")
            .map(String.init)
        let session = SharedCareSession(
            date: record.date(for: "date") ?? metadata.lastModifiedAt,
            actionKind: SharedCareActionKind(rawValue: record.string(for: "actionKindRaw") ?? "") ?? .feeding,
            executorId: record.string(for: "executorId"),
            executorIds: SharedCareParticipantIDs.decode(
                record.string(for: "executorIdsRaw") ?? "",
                fallback: record.string(for: "executorId")
            ),
            sourcePetId: record.string(for: "sourcePetId") ?? "",
            targetPetIds: targetPetIds,
            species: record.string(for: "speciesRaw") ?? "",
            totalAmountGrams: record.double(for: "totalAmountGrams") ?? 0,
            totalAmountMl: record.double(for: "totalAmountMl") ?? 0,
            totalExpenseAmount: record.double(for: "totalExpenseAmount") ?? 0,
            expenseCategory: ExpenseCategory(rawValue: record.string(for: "expenseCategoryRaw") ?? "") ?? .other,
            currencyCode: record.string(for: "currencyCode") ?? "",
            allocationMode: SharedCareAllocationMode(rawValue: record.string(for: "allocationModeRaw") ?? "") ?? .equal,
            foodKind: FeedFoodKind(rawValue: record.string(for: "foodKindRaw") ?? "") ?? .dry,
            stockOwnerPetId: record.string(for: "stockOwnerPetId") ?? "",
            primaryLegacyModelName: record.string(for: "primaryLegacyModelName") ?? "",
            primaryLegacyModelId: record.string(for: "primaryLegacyModelId") ?? "",
            note: record.string(for: "note") ?? ""
        )
        session.id = metadata.localRecordUUID
        session.createdAt = record.date(for: "createdAt") ?? session.createdAt
        context.insert(session)
        return .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
    }

    private static func applyCareLedgerEvent(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let event: CareLedgerEvent
        let result: CloudSyncRecordApplyResult
        if let existing = try fetchCareLedgerEvent(id: metadata.localRecordUUID, context: context) {
            event = existing
            result = .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        } else {
            event = CareLedgerEvent(
                id: metadata.localRecordUUID,
                occurredAt: record.date(for: "occurredAt") ?? metadata.lastModifiedAt,
                actorKind: CareLedgerActorKind(rawValue: record.string(for: "actorKind") ?? "") ?? .unknown,
                actorId: record.string(for: "actorId"),
                subjectKind: CareLedgerSubjectKind(rawValue: record.string(for: "subjectKind") ?? "") ?? .unknown,
                subjectId: record.string(for: "subjectId"),
                eventKind: CareLedgerEventKind(rawValue: record.string(for: "eventKind") ?? "") ?? .unknown,
                actionType: record.string(for: "actionType") ?? "",
                source: CareLedgerSource(rawValue: record.string(for: "source") ?? "") ?? .service,
                createdAt: record.date(for: "createdAt") ?? metadata.lastModifiedAt
            )
            context.insert(event)
            result = .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        event.occurredAt = record.date(for: "occurredAt") ?? event.occurredAt
        event.actorKind = record.string(for: "actorKind") ?? event.actorKind
        event.actorId = record.string(for: "actorId")
        event.subjectKind = record.string(for: "subjectKind") ?? event.subjectKind
        event.subjectId = record.string(for: "subjectId")
        event.eventKind = record.string(for: "eventKind") ?? event.eventKind
        event.actionType = record.string(for: "actionType") ?? event.actionType
        event.amountValue = record.double(for: "amountValue") ?? event.amountValue
        event.amountUnit = record.string(for: "amountUnit") ?? event.amountUnit
        event.note = record.string(for: "note") ?? event.note
        event.source = record.string(for: "source") ?? event.source
        event.sourceEventId = record.string(for: "sourceEventId")
        event.sourceReminderId = record.string(for: "sourceReminderId")
        event.legacyModelName = record.string(for: "legacyModelName")
        event.legacyModelId = record.string(for: "legacyModelId")
        event.coconutDelta = record.int(for: "coconutDelta") ?? event.coconutDelta
        event.rewardLogId = record.string(for: "rewardLogId")
        event.privacyFieldRaw = record.string(for: "privacyFieldRaw")
        event.metadataJSON = record.string(for: "metadataJSON") ?? event.metadataJSON
        event.createdAt = record.date(for: "createdAt") ?? event.createdAt
        return result
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
            accountKey: record.string(for: "accountKey") ?? "system:legacy",
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
                isDeletionTombstone: metadata.isDeleted,
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
        try deleteLocalModel(
            entityName: metadata.entityName,
            localRecordUUID: metadata.localRecordUUID,
            context: context
        )
    }

    private static func deleteLocalModel(
        entityName: String,
        localRecordUUID: UUID,
        context: ModelContext
    ) throws {
        switch entityName {
        case String(describing: Household.self):
            if let model = try fetchHousehold(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: Pet.self):
            if let model = try fetchPet(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: Human.self):
            if let model = try fetchHuman(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetCareLog.self):
            if let model = try fetchPetCareLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetPottyLog.self):
            if let model = try fetchPetPottyLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetHygieneLog.self):
            if let model = try fetchPetHygieneLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetHealthLog.self):
            if let model = try fetchPetHealthLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetWalkLog.self):
            if let model = try fetchPetWalkLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetExpenseLog.self):
            if let model = try fetchPetExpenseLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: PetWeightLog.self):
            if let model = try fetchPetWeightLog(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: SharedCareSession.self):
            if let model = try fetchSharedCareSession(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: CareLedgerEvent.self):
            if let model = try fetchCareLedgerEvent(id: localRecordUUID, context: context) {
                context.delete(model)
            }
        case String(describing: CoconutLedgerEntry.self):
            if let model = try fetchCoconutLedgerEntry(id: localRecordUUID, context: context) {
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

    private static func fetchSharedCareSession(id: UUID, context: ModelContext) throws -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchCareLedgerEvent(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.id == id }
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

private nonisolated struct RemoteMetadata {
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
            ?? CloudSyncRecordIdentityParser.localRecordIdFromRecordName(
                record.recordID.recordName,
                entityName: entityName
            )
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
            ?? CloudSyncRecordIdentityParser.householdIdFromZoneName(record.recordID.zoneID.zoneName)
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
}

private nonisolated enum CloudSyncRecordIdentityParser {
    static func localRecordIdFromRecordName(_ recordName: String, entityName: String) -> String? {
        let prefix = "\(entityName)_"
        guard recordName.hasPrefix(prefix) else { return nil }
        return String(recordName.dropFirst(prefix.count))
    }

    static func householdIdFromZoneName(_ zoneName: String) -> String? {
        let prefix = "household-"
        guard zoneName.hasPrefix(prefix) else { return nil }
        return String(zoneName.dropFirst(prefix.count))
    }
}

private extension CKRecord {
    nonisolated func string(for key: String) -> String? {
        if let value = self[key] as? String {
            return value
        }
        if let value = self[key] as? NSString {
            return value as String
        }
        return nil
    }

    nonisolated func int(for key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        return nil
    }

    nonisolated func double(for key: String) -> Double? {
        if let value = self[key] as? Double {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    nonisolated func bool(for key: String) -> Bool? {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.boolValue
        }
        return nil
    }

    nonisolated func date(for key: String) -> Date? {
        if let value = self[key] as? Date {
            return value
        }
        if let value = self[key] as? NSDate {
            return value as Date
        }
        return nil
    }

    nonisolated func assetData(for key: String) -> Data? {
        guard let asset = self[key] as? CKAsset,
              let fileURL = asset.fileURL else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }
}
