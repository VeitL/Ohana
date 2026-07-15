//
//  CloudSyncRecordSerializer.swift
//  Ohana
//
//  Narrow SwiftData-to-CloudKit record mapping for the future CKSyncEngine queue.
//

import CloudKit
import Foundation

nonisolated enum CloudSyncRecordSerializationError: LocalizedError, Equatable {
    case missingDescriptor(entityName: String)
    case notUploadable(entityName: String)
    case missingLocalRecordId(entityName: String)
    case mismatchedState(entityName: String, expected: String, actual: String)
    case unsupportedEntity(entityName: String)
    case missingAssetFileURL(fieldName: String)

    var errorDescription: String? {
        switch self {
        case let .missingDescriptor(entityName):
            "Cloud sync descriptor is missing for \(entityName)."
        case let .notUploadable(entityName):
            "\(entityName) is local-only or derived and cannot be uploaded to CloudKit."
        case let .missingLocalRecordId(entityName):
            "\(entityName) does not expose a stable UUID for CloudKit serialization."
        case let .mismatchedState(entityName, expected, actual):
            "\(entityName) sync state points at \(expected), but the local model is \(actual)."
        case let .unsupportedEntity(entityName):
            "\(entityName) does not have a CloudKit field mapper yet."
        case let .missingAssetFileURL(fieldName):
            "\(fieldName) contains binary asset data, but no asset file URL provider was supplied."
        }
    }
}

nonisolated enum CloudSyncRecordFieldValue: Equatable, Sendable {
    case null
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case stringList([String])
    case assetData(Data)

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case let .int(value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    var dateValue: Date? {
        guard case let .date(value) = self else { return nil }
        return value
    }

    var stringListValue: [String]? {
        guard case let .stringList(value) = self else { return nil }
        return value
    }
}

nonisolated struct CloudSyncRecordPayload: Equatable, Sendable {
    typealias AssetFileURLProvider = @Sendable (_ fieldName: String, _ data: Data) throws -> URL

    let entityName: String
    let recordType: String
    let recordName: String
    let zoneName: String
    let localRecordId: String
    let householdId: String
    let isDeleted: Bool
    let fields: [String: CloudSyncRecordFieldValue]

    nonisolated func makeCKRecord(
        ownerName: String = CKCurrentUserDefaultName,
        assetFileURLProvider: AssetFileURLProvider? = nil
    ) throws -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        for (fieldName, value) in fields {
            switch value {
            case .null:
                record[fieldName] = nil
            case let .string(string):
                record[fieldName] = string as CKRecordValue
            case let .int(int):
                record[fieldName] = int as CKRecordValue
            case let .double(double):
                record[fieldName] = double as CKRecordValue
            case let .bool(bool):
                record[fieldName] = bool as CKRecordValue
            case let .date(date):
                record[fieldName] = date as CKRecordValue
            case let .stringList(strings):
                record[fieldName] = strings as NSArray
            case let .assetData(data):
                guard let assetFileURLProvider else {
                    throw CloudSyncRecordSerializationError.missingAssetFileURL(fieldName: fieldName)
                }
                record[fieldName] = try CKAsset(fileURL: assetFileURLProvider(fieldName, data))
            }
        }

        return record
    }
}

nonisolated enum CloudSyncRecordFieldKey {
    static let recordKey = "sync_recordKey"
    static let entityName = "sync_entityName"
    static let localRecordId = "sync_localRecordId"
    static let householdId = "sync_householdId"
    static let isDeleted = "sync_isDeleted"
    static let deletedAt = "sync_deletedAt"
    static let deletedByHumanId = "sync_deletedByHumanId"
    static let lastModifiedAt = "sync_lastModifiedAt"
    static let conflictPolicy = "sync_conflictPolicy"
}

nonisolated enum CloudSyncZoneNaming {
    static let unassignedPrivateZoneName = "ohana-private-unassigned"

    static func zoneName(forHouseholdId householdId: String) -> String {
        let normalized = CloudSyncRecordState.normalizedRecordId(householdId)
        guard !normalized.isEmpty else { return unassignedPrivateZoneName }
        return "household-\(normalized)"
    }

    static func recordName(entityName: String, localRecordId: String) -> String {
        "\(CloudSyncRecordState.normalizedEntityName(entityName))_\(CloudSyncRecordState.normalizedRecordId(localRecordId))"
    }
}

nonisolated enum CloudSyncRecordSerializer {
    static func payload(
        for model: Any,
        state: CloudSyncRecordState
    ) throws -> CloudSyncRecordPayload {
        let descriptor = try uploadableDescriptor(for: state.entityName)
        let modelRecordId = try localRecordId(for: model, entityName: descriptor.entityName)
        let expectedRecordId = CloudSyncRecordState.normalizedRecordId(state.localRecordId)
        guard modelRecordId == expectedRecordId else {
            throw CloudSyncRecordSerializationError.mismatchedState(
                entityName: descriptor.entityName,
                expected: expectedRecordId,
                actual: modelRecordId
            )
        }

        let rawFields = try localFields(for: model, entityName: descriptor.entityName)
        return payload(
            descriptor: descriptor,
            state: state,
            rawFields: rawFields,
            isDeleted: state.isDeletionTombstone
        )
    }

    static func tombstonePayload(for state: CloudSyncRecordState) throws -> CloudSyncRecordPayload {
        let descriptor = try uploadableDescriptor(for: state.entityName)
        return payload(
            descriptor: descriptor,
            state: state,
            rawFields: [:],
            isDeleted: true
        )
    }

    private static func uploadableDescriptor(for entityName: String) throws -> CloudSyncEntityDescriptor {
        let normalizedEntityName = CloudSyncRecordState.normalizedEntityName(entityName)
        guard let descriptor = CloudSyncEntityRegistry.descriptor(for: normalizedEntityName) else {
            throw CloudSyncRecordSerializationError.missingDescriptor(entityName: normalizedEntityName)
        }
        guard descriptor.uploadsToCloudKit,
              CloudSyncEntityRegistry.supportsUploadPipeline(for: normalizedEntityName) else {
            throw CloudSyncRecordSerializationError.notUploadable(entityName: normalizedEntityName)
        }
        return descriptor
    }

    private static func payload(
        descriptor: CloudSyncEntityDescriptor,
        state: CloudSyncRecordState,
        rawFields: [String: CloudSyncRecordFieldValue],
        isDeleted: Bool
    ) -> CloudSyncRecordPayload {
        let recordName = state.ckRecordName.isEmpty
            ? CloudSyncZoneNaming.recordName(entityName: descriptor.entityName, localRecordId: state.localRecordId)
            : state.ckRecordName
        let zoneName = state.ckZoneName.isEmpty
            ? CloudSyncZoneNaming.zoneName(forHouseholdId: state.householdId)
            : state.ckZoneName
        var fields = rawFields.filter { descriptor.shouldUploadField($0.key) }
        fields.merge(metadataFields(for: state, isDeleted: isDeleted)) { _, metadata in metadata }

        return CloudSyncRecordPayload(
            entityName: descriptor.entityName,
            recordType: descriptor.recordType,
            recordName: recordName,
            zoneName: zoneName,
            localRecordId: CloudSyncRecordState.normalizedRecordId(state.localRecordId),
            householdId: CloudSyncRecordState.normalizedRecordId(state.householdId),
            isDeleted: isDeleted,
            fields: fields
        )
    }

    private static func metadataFields(
        for state: CloudSyncRecordState,
        isDeleted: Bool
    ) -> [String: CloudSyncRecordFieldValue] {
        var fields: [String: CloudSyncRecordFieldValue] = [
            CloudSyncRecordFieldKey.recordKey: .string(state.recordKey),
            CloudSyncRecordFieldKey.entityName: .string(state.entityName),
            CloudSyncRecordFieldKey.localRecordId: .string(CloudSyncRecordState.normalizedRecordId(state.localRecordId)),
            CloudSyncRecordFieldKey.householdId: .string(CloudSyncRecordState.normalizedRecordId(state.householdId)),
            CloudSyncRecordFieldKey.isDeleted: .bool(isDeleted),
            CloudSyncRecordFieldKey.lastModifiedAt: .date(state.lastModifiedAt),
            CloudSyncRecordFieldKey.conflictPolicy: .string(state.conflictPolicy.rawValue)
        ]

        if let deletedAt = state.deletedAt, isDeleted {
            fields[CloudSyncRecordFieldKey.deletedAt] = .date(deletedAt)
        }
        if !state.deletedByHumanId.isEmpty, isDeleted {
            fields[CloudSyncRecordFieldKey.deletedByHumanId] = .string(state.deletedByHumanId)
        }

        return fields
    }

    private static func localRecordId(for model: Any, entityName: String) throws -> String {
        switch model {
        case let household as Household:
            CloudSyncRecordState.normalizedRecordId(household.id)
        case let pet as Pet:
            CloudSyncRecordState.normalizedRecordId(pet.id)
        case let human as Human:
            CloudSyncRecordState.normalizedRecordId(human.id)
        case let event as Event:
            CloudSyncRecordState.normalizedRecordId(event.id)
        case let log as PetCareLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as PetPottyLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as PetHygieneLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as PetHealthLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as PetWalkLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as PetExpenseLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let record as PetFoodRecord:
            CloudSyncRecordState.normalizedRecordId(record.id)
        case let log as PetWeightLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as SymptomLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let log as HeatCycleLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let session as SharedCareSession:
            CloudSyncRecordState.normalizedRecordId(session.id)
        case let event as CareLedgerEvent:
            CloudSyncRecordState.normalizedRecordId(event.id)
        case let entry as CoconutLedgerEntry:
            CloudSyncRecordState.normalizedRecordId(entry.id)
        case let item as GachaOwnedItem:
            CloudSyncRecordState.normalizedRecordId(item.id)
        case let log as GachaDrawLog:
            CloudSyncRecordState.normalizedRecordId(log.id)
        case let record as ShopPurchaseRecord:
            CloudSyncRecordState.normalizedRecordId(record.id)
        default:
            throw CloudSyncRecordSerializationError.missingLocalRecordId(entityName: entityName)
        }
    }

    private static func localFields(
        for model: Any,
        entityName: String
    ) throws -> [String: CloudSyncRecordFieldValue] {
        if let observationFields = petObservationFields(for: model) {
            return observationFields
        }
        return try coreLocalFields(for: model, entityName: entityName)
    }

    private static func coreLocalFields(
        for model: Any,
        entityName: String
    ) throws -> [String: CloudSyncRecordFieldValue] {
        var fields: [String: CloudSyncRecordFieldValue]
        switch model {
        case let household as Household:
            fields = householdFields(household)
        case let pet as Pet:
            fields = petFields(pet)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: pet.trashedAt,
                trashExpiresAt: pet.trashExpiresAt,
                trashBatchId: pet.trashBatchId,
                trashedByHumanId: pet.trashedByHumanId
            )
        case let human as Human:
            fields = humanFields(human)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: human.trashedAt,
                trashExpiresAt: human.trashExpiresAt,
                trashBatchId: human.trashBatchId,
                trashedByHumanId: human.trashedByHumanId
            )
        case let event as Event:
            fields = eventFields(event)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: event.trashedAt,
                trashExpiresAt: event.trashExpiresAt,
                trashBatchId: event.trashBatchId,
                trashedByHumanId: event.trashedByHumanId
            )
        case let log as PetCareLog:
            fields = petCareLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let log as PetPottyLog:
            fields = petPottyLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let log as PetHygieneLog:
            fields = petHygieneLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let log as PetHealthLog:
            fields = petHealthLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let log as PetWalkLog:
            fields = petWalkLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let log as PetExpenseLog:
            fields = petExpenseLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let record as PetFoodRecord:
            fields = petFoodRecordFields(record)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: record.trashedAt,
                trashExpiresAt: record.trashExpiresAt,
                trashBatchId: record.trashBatchId,
                trashedByHumanId: record.trashedByHumanId
            )
        case let log as PetWeightLog:
            fields = petWeightLogFields(log)
            mergeLegacyRecycleBinFields(
                into: &fields,
                trashedAt: log.trashedAt,
                trashExpiresAt: log.trashExpiresAt,
                trashBatchId: log.trashBatchId,
                trashedByHumanId: log.trashedByHumanId
            )
        case let session as SharedCareSession:
            fields = sharedCareSessionFields(session)
        case let event as CareLedgerEvent:
            fields = careLedgerEventFields(event)
        case let entry as CoconutLedgerEntry:
            fields = coconutLedgerEntryFields(entry)
        case let item as GachaOwnedItem:
            fields = gachaOwnedItemFields(item)
        case let log as GachaDrawLog:
            fields = gachaDrawLogFields(log)
        case let record as ShopPurchaseRecord:
            fields = shopPurchaseRecordFields(record)
        default:
            throw CloudSyncRecordSerializationError.unsupportedEntity(entityName: entityName)
        }
        return fields
    }

    private static func petObservationFields(for model: Any) -> [String: CloudSyncRecordFieldValue]? {
        var fields: [String: CloudSyncRecordFieldValue]
        let recycleBinFields: (Date?, Date?, String, String)
        switch model {
        case let log as SymptomLog:
            fields = symptomLogFields(log)
            recycleBinFields = (log.trashedAt, log.trashExpiresAt, log.trashBatchId, log.trashedByHumanId)
        case let log as HeatCycleLog:
            fields = heatCycleLogFields(log)
            recycleBinFields = (log.trashedAt, log.trashExpiresAt, log.trashBatchId, log.trashedByHumanId)
        default:
            return nil
        }
        mergeLegacyRecycleBinFields(
            into: &fields,
            trashedAt: recycleBinFields.0,
            trashExpiresAt: recycleBinFields.1,
            trashBatchId: recycleBinFields.2,
            trashedByHumanId: recycleBinFields.3
        )
        return fields
    }

    private static func householdFields(_ household: Household) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(household.id)),
            "name": .string(household.name),
            "createdAt": .date(household.createdAt),
            "ckShareRecordName": .string(household.ckShareRecordName),
            "totalProsperity": .int(household.totalProsperity)
        ]
    }

    private static func petFields(_ pet: Pet) -> [String: CloudSyncRecordFieldValue] {
        var fields: [String: CloudSyncRecordFieldValue] = [
            "id": .string(CloudSyncRecordState.normalizedRecordId(pet.id)),
            "name": .string(pet.name),
            "species": .string(pet.species),
            "breed": .string(pet.breed),
            "birthday": optionalDate(pet.birthday),
            "gender": .string(pet.gender),
            "isNeutered": .bool(pet.isNeutered),
            "avatarEmoji": .string(pet.avatarEmoji),
            "microchipID": .string(pet.microchipID),
            "vetContact": .string(pet.vetContact),
            "vetClinicName": .string(pet.vetClinicName),
            "vetDoctorName": .string(pet.vetDoctorName),
            "vetAddress": .string(pet.vetAddress),
            "allergies": .string(pet.allergies),
            "passportNumber": .string(pet.passportNumber),
            "passportExpiryDate": optionalDate(pet.passportExpiryDate),
            "formerName": .string(pet.formerName),
            "lineageInfo": .string(pet.lineageInfo),
            "themeColorHex": .string(pet.themeColorHex),
            "homeDate": optionalDate(pet.homeDate),
            "birthCountry": .string(pet.birthCountry),
            "birthCity": .string(pet.birthCity),
            "foodBrand": .string(pet.foodBrand),
            "restockDate": optionalDate(pet.restockDate),
            "restockWeight": .double(pet.restockWeight),
            "dailyPortionGrams": .double(pet.dailyPortionGrams),
            "mainFoodKindRaw": .string(pet.mainFoodKindRaw),
            "foodPrice": .double(pet.foodPrice),
            "isShared": .bool(pet.isShared),
            "ckRecordName": .string(pet.ckRecordName),
            "createdAt": .date(pet.createdAt),
            "notes": .string(pet.notes),
            "coatColor": .string(pet.coatColor),
            "eyeColor": .string(pet.eyeColor),
            "currentStreak": .int(pet.currentStreak),
            "lastCheckInDate": optionalDate(pet.lastCheckInDate),
            "foodTrackingModeRaw": .string(pet.foodTrackingModeRaw),
            "casualOpenDate": optionalDate(pet.casualOpenDate),
            "casualDurationDays": .int(pet.casualDurationDays),
            "foodReminderEnabled": .bool(pet.foodReminderEnabled),
            "foodReminderAdvanceDays": .int(pet.foodReminderAdvanceDays),
            "coconutBalance": .int(pet.coconutBalance),
            "passedAwayDate": optionalDate(pet.passedAwayDate),
            "cardStyleRaw": .string(pet.cardStyleRaw),
            "cardPopoutSourceRaw": optionalString(pet.cardPopoutSourceRaw),
            "weeklyWalkGoalKm": .double(pet.weeklyWalkGoalKm),
            "personalityTagsRaw": .string(pet.personalityTagsRaw)
        ]
        if let avatarImageData = pet.avatarImageData {
            fields["avatarImageData"] = .assetData(avatarImageData)
        }
        if let cardPopoutImageData = pet.cardPopoutImageData {
            fields["cardPopoutImageData"] = .assetData(cardPopoutImageData)
        }
        return fields
    }

    private static func humanFields(_ human: Human) -> [String: CloudSyncRecordFieldValue] {
        var fields: [String: CloudSyncRecordFieldValue] = [
            "id": .string(CloudSyncRecordState.normalizedRecordId(human.id)),
            "name": .string(human.name),
            "birthday": optionalDate(human.birthday),
            "bloodType": .string(human.bloodType),
            "avatarEmoji": .string(human.avatarEmoji),
            "role": .string(human.role),
            "appleUserIdentifier": .string(human.appleUserIdentifier),
            "notes": .string(human.notes),
            "createdAt": .date(human.createdAt),
            "nationality": .string(human.nationality),
            "city": .string(human.city),
            "coconutBalance": .int(human.coconutBalance),
            "shouldShowOnHome": .bool(human.shouldShowOnHome),
            "themeColorHex": .string(human.themeColorHex),
            "genderIdentityRaw": optionalString(human.genderIdentityRaw),
            "privateFieldsRaw": .string(human.privateFieldsRaw),
            "heightCm": .double(human.heightCm),
            "mbti": .string(human.mbti),
            "pinHash": .string(human.pinHash),
            "pinSalt": .string(human.pinSalt),
            "pinFailedAttempts": .int(human.pinFailedAttempts),
            "pinLockedUntil": optionalDate(human.pinLockedUntil),
            "passedAwayDate": optionalDate(human.passedAwayDate)
        ]
        if let avatarImageData = human.avatarImageData {
            fields["avatarImageData"] = .assetData(avatarImageData)
        }
        return fields
    }

    private static func eventFields(_ event: Event) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(event.id)),
            "title": .string(event.title),
            "startDate": .date(event.startDate),
            "endDate": optionalDate(event.endDate),
            "isAllDay": .bool(event.isAllDay),
            "eventType": .string(event.eventType),
            "relatedEntityType": .string(event.relatedEntityType),
            "relatedEntityId": .string(event.relatedEntityId),
            "recurrenceDays": .int(event.recurrenceDays),
            "recurrenceEndDate": optionalDate(event.recurrenceEndDate),
            "isCompleted": .bool(event.isCompleted),
            "completedOccurrences": .stringList(event.completedOccurrences),
            "createdAt": .date(event.createdAt),
            "assigneeId": optionalString(event.assigneeId),
            "feedRuleKindRaw": .string(event.feedRuleKindRaw),
            "foodKindRaw": .string(event.foodKindRaw),
            "feedAmountGrams": .double(event.feedAmountGrams),
            "feedPlanGroupId": .string(event.feedPlanGroupId)
        ]
    }

    private static func petCareLogFields(_ log: PetCareLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "type": .string(log.type),
            "amountGrams": .double(log.amountGrams),
            "amountMl": .double(log.amountMl),
            "note": .string(log.note),
            "foodKindRaw": .string(log.foodKindRaw),
            "treatKindRaw": .string(log.treatKindRaw),
            "autoFeedDedupKey": .string(log.autoFeedDedupKey),
            "sharedSessionId": .string(log.sharedSessionId),
            "executorId": optionalString(log.executorId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func petPottyLogFields(_ log: PetPottyLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "type": .string(log.type),
            "executorId": optionalString(log.executorId),
            "latitude": optionalDouble(log.latitude),
            "longitude": optionalDouble(log.longitude),
            "locationAccuracyMeters": optionalDouble(log.locationAccuracyMeters),
            "walkLogId": optionalString(log.walkLogId),
            "sharedSessionId": .string(log.sharedSessionId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func petHygieneLogFields(_ log: PetHygieneLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "type": .string(log.type),
            "executorId": optionalString(log.executorId),
            "sharedSessionId": .string(log.sharedSessionId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func petHealthLogFields(_ log: PetHealthLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "type": .string(log.type),
            "note": .string(log.note),
            "vetName": .string(log.vetName),
            "cost": .double(log.cost),
            "expirationDate": optionalDate(log.expirationDate),
            "nextCheckupDate": optionalDate(log.nextCheckupDate),
            "executorId": optionalString(log.executorId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func petWalkLogFields(_ log: PetWalkLog) -> [String: CloudSyncRecordFieldValue] {
        var fields: [String: CloudSyncRecordFieldValue] = [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "startDate": .date(log.startDate),
            "endDate": optionalDate(log.endDate),
            "distanceMeters": .double(log.distanceMeters),
            "coconutsEarned": .int(log.coconutsEarned),
            "executorId": optionalString(log.executorId),
            "executorIdsRaw": .string(SharedCareParticipantIDs.encode(log.executorIds)),
            "sharedSessionId": .string(log.sharedSessionId),
            "behaviorNotes": optionalString(log.behaviorNotes),
            "moodRating": .int(log.moodRating),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
        if let mapSnapshotData = log.mapSnapshotData {
            fields["mapSnapshotData"] = .assetData(mapSnapshotData)
        }
        if let routeLocationsData = log.routeLocationsData {
            fields["routeLocationsData"] = .assetData(routeLocationsData)
        }
        return fields
    }

    private static func petExpenseLogFields(_ log: PetExpenseLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "amount": .double(log.amount),
            "category": .string(log.category),
            "note": .string(log.note),
            "sharedSessionId": .string(log.sharedSessionId),
            "executorId": optionalString(log.executorId),
            "recordedByHumanId": optionalString(log.recordedByHumanId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func petFoodRecordFields(_ record: PetFoodRecord) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(record.id)),
            "brand": .string(record.brand),
            "dailyGrams": .double(record.dailyGrams),
            "totalGrams": .double(record.totalGrams),
            "foodKindRaw": .string(record.foodKindRaw),
            "purchaseDate": optionalDate(record.purchaseDate),
            "startDate": .date(record.startDate),
            "remainingCorrectionGrams": optionalDouble(record.remainingCorrectionGrams),
            "remainingCorrectionDate": optionalDate(record.remainingCorrectionDate),
            "notes": .string(record.notes),
            "expenseId": optionalString(record.expenseId.map(CloudSyncRecordState.normalizedRecordId)),
            "calculationModeRaw": .string(record.calculationModeRaw),
            "executorId": optionalString(record.executorId),
            "petId": optionalString(record.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func petWeightLogFields(_ log: PetWeightLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "weight": .double(log.weight),
            "weightUnit": .string(log.weightUnit),
            "bcsScore": .int(log.bcsScore),
            "executorId": optionalString(log.executorId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func symptomLogFields(_ log: SymptomLog) -> [String: CloudSyncRecordFieldValue] {
        var fields: [String: CloudSyncRecordFieldValue] = [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "date": .date(log.date),
            "categoryRaw": .string(log.categoryRaw),
            "symptomName": .string(log.symptomName),
            "severityRaw": .int(log.severityRaw),
            "note": .string(log.note),
            "recordedByHumanId": optionalString(log.recordedByHumanId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
        if let photoData = log.photoData {
            fields["photoData"] = .assetData(photoData)
        }
        return fields
    }

    private static func heatCycleLogFields(_ log: HeatCycleLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "startDate": .date(log.startDate),
            "endDate": optionalDate(log.endDate),
            "statusRaw": .string(log.statusRaw),
            "note": .string(log.note),
            "isMated": .bool(log.isMated),
            "expectedDeliveryDate": optionalDate(log.expectedDeliveryDate),
            "recordedByHumanId": optionalString(log.recordedByHumanId),
            "petId": optionalString(log.pet.map { CloudSyncRecordState.normalizedRecordId($0.id) })
        ]
    }

    private static func sharedCareSessionFields(_ session: SharedCareSession) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(session.id)),
            "date": .date(session.date),
            "actionKindRaw": .string(session.actionKindRaw),
            "executorId": optionalString(session.executorId),
            "executorIdsRaw": .string(SharedCareParticipantIDs.encode(session.executorIds)),
            "sourcePetId": .string(session.sourcePetId),
            "targetPetIdsRaw": .string(session.targetPetIdsRaw),
            "speciesRaw": .string(session.speciesRaw),
            "totalAmountGrams": .double(session.totalAmountGrams),
            "totalAmountMl": .double(session.totalAmountMl),
            "totalExpenseAmount": .double(session.totalExpenseAmount),
            "expenseCategoryRaw": .string(session.expenseCategoryRaw),
            "currencyCode": .string(session.currencyCode),
            "allocationModeRaw": .string(session.allocationModeRaw),
            "foodKindRaw": .string(session.foodKindRaw),
            "stockOwnerPetId": .string(session.stockOwnerPetId),
            "primaryLegacyModelName": .string(session.primaryLegacyModelName),
            "primaryLegacyModelId": .string(session.primaryLegacyModelId),
            "note": .string(session.note),
            "createdAt": .date(session.createdAt)
        ]
    }

    private static func careLedgerEventFields(_ event: CareLedgerEvent) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(event.id)),
            "occurredAt": .date(event.occurredAt),
            "actorKind": .string(event.actorKind),
            "actorId": optionalString(event.actorId),
            "subjectKind": .string(event.subjectKind),
            "subjectId": optionalString(event.subjectId),
            "eventKind": .string(event.eventKind),
            "actionType": .string(event.actionType),
            "amountValue": .double(event.amountValue),
            "amountUnit": .string(event.amountUnit),
            "note": .string(event.note),
            "source": .string(event.source),
            "sourceEventId": optionalString(event.sourceEventId),
            "sourceReminderId": optionalString(event.sourceReminderId),
            "legacyModelName": optionalString(event.legacyModelName),
            "legacyModelId": optionalString(event.legacyModelId),
            "coconutDelta": .int(event.coconutDelta),
            "rewardLogId": optionalString(event.rewardLogId),
            "privacyFieldRaw": optionalString(event.privacyFieldRaw),
            "metadataJSON": .string(event.metadataJSON),
            "createdAt": .date(event.createdAt)
        ]
    }

    private static func coconutLedgerEntryFields(_ entry: CoconutLedgerEntry) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(entry.id)),
            "transactionKey": .string(entry.transactionKey),
            "accountKey": .string(entry.accountKey),
            "ownerKindRaw": .string(entry.ownerKindRaw),
            "ownerId": .string(entry.ownerId),
            "ownerName": .string(entry.ownerName),
            "delta": .int(entry.delta),
            "balanceBefore": .int(entry.balanceBefore),
            "balanceAfter": .int(entry.balanceAfter),
            "affectsBalance": .bool(entry.affectsBalance),
            "entryKindRaw": .string(entry.entryKindRaw),
            "sourceRaw": .string(entry.sourceRaw),
            "title": .string(entry.title),
            "emoji": .string(entry.emoji),
            "actorId": optionalString(entry.actorId),
            "actorName": optionalString(entry.actorName),
            "subjectKindRaw": .string(entry.subjectKindRaw),
            "subjectId": optionalString(entry.subjectId),
            "sourceModelName": .string(entry.sourceModelName),
            "sourceModelId": .string(entry.sourceModelId),
            "careLedgerEventId": optionalString(entry.careLedgerEventId),
            "metadataJSON": .string(entry.metadataJSON),
            "occurredAt": .date(entry.occurredAt),
            "createdAt": .date(entry.createdAt)
        ]
    }

    private static func gachaOwnedItemFields(_ item: GachaOwnedItem) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(item.id)),
            "ownerHumanId": .string(item.ownerHumanId),
            "seriesId": .string(item.seriesId),
            "itemId": .string(item.itemId),
            "rarityRaw": .string(item.rarityRaw),
            "isHidden": .bool(item.isHidden),
            "ownedCount": .int(item.ownedCount),
            "firstObtainedAt": .date(item.firstObtainedAt),
            "latestObtainedAt": .date(item.latestObtainedAt),
            "createdAt": .date(item.createdAt)
        ]
    }

    private static func gachaDrawLogFields(_ log: GachaDrawLog) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(log.id)),
            "ownerHumanId": .string(log.ownerHumanId),
            "ownerName": .string(log.ownerName),
            "seriesId": .string(log.seriesId),
            "itemId": .string(log.itemId),
            "rarityRaw": .string(log.rarityRaw),
            "isHidden": .bool(log.isHidden),
            "isNew": .bool(log.isNew),
            "outcomeKindRaw": .string(log.outcomeKindRaw),
            "instantResultId": .string(log.instantResultId),
            "instantTitleZh": .string(log.instantTitleZh),
            "instantTitleEn": .string(log.instantTitleEn),
            "instantTitleDe": .string(log.instantTitleDe),
            "instantDetailZh": .string(log.instantDetailZh),
            "instantDetailEn": .string(log.instantDetailEn),
            "instantDetailDe": .string(log.instantDetailDe),
            "instantSymbol": .string(log.instantSymbol),
            "instantCoconutDelta": .int(log.instantCoconutDelta),
            "costCoconuts": .int(log.costCoconuts),
            "dailySequence": .int(log.dailySequence),
            "drawDate": .date(log.drawDate),
            "createdAt": .date(log.createdAt)
        ]
    }

    private static func shopPurchaseRecordFields(_ record: ShopPurchaseRecord) -> [String: CloudSyncRecordFieldValue] {
        [
            "id": .string(CloudSyncRecordState.normalizedRecordId(record.id)),
            "transactionKey": .string(record.transactionKey),
            "itemId": .string(record.itemId),
            "buyerHumanId": .string(record.buyerHumanId),
            "purchasedAt": .date(record.purchasedAt),
            "sourceRaw": .string(record.sourceRaw),
            "isLegacyImport": .bool(record.isLegacyImport),
            "createdAt": .date(record.createdAt)
        ]
    }

    private static func mergeLegacyRecycleBinFields(
        into fields: inout [String: CloudSyncRecordFieldValue],
        trashedAt: Date?,
        trashExpiresAt: Date?,
        trashBatchId: String,
        trashedByHumanId: String
    ) {
        fields[CloudSyncLegacyRecycleBinFieldKey.trashedAt] = optionalDate(trashedAt)
        fields[CloudSyncLegacyRecycleBinFieldKey.trashExpiresAt] = optionalDate(trashExpiresAt)
        fields[CloudSyncLegacyRecycleBinFieldKey.trashBatchId] = .string(trashBatchId)
        fields[CloudSyncLegacyRecycleBinFieldKey.trashedByHumanId] = .string(trashedByHumanId)
    }

    private static func optionalString(_ value: String?) -> CloudSyncRecordFieldValue {
        guard let value else { return .null }
        return .string(value)
    }

    private static func optionalDate(_ value: Date?) -> CloudSyncRecordFieldValue {
        guard let value else { return .null }
        return .date(value)
    }

    private static func optionalDouble(_ value: Double?) -> CloudSyncRecordFieldValue {
        guard let value else { return .null }
        return .double(value)
    }
}
