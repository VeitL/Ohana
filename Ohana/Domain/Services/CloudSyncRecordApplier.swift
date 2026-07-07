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

private nonisolated struct CloudSyncRecordApplyOutcome {
    let result: CloudSyncRecordApplyResult
    let stateLocalRecordUUID: UUID?
    let notificationIdsToCancel: [String]

    init(
        result: CloudSyncRecordApplyResult,
        stateLocalRecordUUID: UUID? = nil,
        notificationIdsToCancel: [String] = []
    ) {
        self.result = result
        self.stateLocalRecordUUID = stateLocalRecordUUID
        self.notificationIdsToCancel = notificationIdsToCancel
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
        let existingState = try existingAppliedState(metadata: metadata, record: record, context: context)
        let existingStateRecordUUID = localRecordUUID(from: existingState)
        if let existingState,
           existingState.lastModifiedAt > metadata.lastModifiedAt {
            return .skippedStale(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        if metadata.isDeleted {
            let deletedRecordUUID = existingStateRecordUUID ?? metadata.localRecordUUID
            try deleteLocalModel(
                entityName: metadata.entityName,
                localRecordUUID: deletedRecordUUID,
                deletedAt: metadata.deletedAt ?? metadata.lastModifiedAt,
                deletedByHumanId: normalizedDeletionActorId(metadata.deletedByHumanId),
                context: context
            )
            let state = try upsertState(
                metadata: metadata,
                record: record,
                context: context,
                localRecordUUID: deletedRecordUUID
            )
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
            return .deleted(
                entityName: metadata.entityName,
                localRecordId: CloudSyncRecordState.normalizedRecordId(deletedRecordUUID)
            )
        }

        if let existingState,
           existingState.isDeletionTombstone || existingState.isDeleted {
            return .skippedStale(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        }

        let outcome = try applyLiveRecord(record, metadata: metadata, descriptor: descriptor, context: context)
        let result = outcome.result
        if case .skippedUnsupported = result {
            return result
        }
        let state = try upsertState(
            metadata: metadata,
            record: record,
            context: context,
            localRecordUUID: outcome.stateLocalRecordUUID ?? existingStateRecordUUID ?? metadata.localRecordUUID
        )
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
        if !outcome.notificationIdsToCancel.isEmpty {
            try saveCloudSyncApplyChanges(context: context)
            DomainRehydrateEffectsDispatcher.cancelNotifications(outcome.notificationIdsToCancel)
        }
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
            deletedAt: deletedAt,
            deletedByHumanId: nil,
            context: context
        )
        let state = try CloudSyncMetadataService.upsertAppliedRemoteState(
            snapshot: CloudSyncAppliedRecordStateSnapshot(
                recordKey: recordKey,
                entityName: descriptor.entityName,
                localRecordId: localRecordUUID,
                householdId: householdUUID,
                ckZoneName: recordID.zoneID.zoneName,
                ckRecordName: recordID.recordName,
                ckChangeTag: "",
                conflictPolicy: matchedState?.conflictPolicy ?? descriptor.defaultConflictPolicy,
                isDeleted: true,
                isDeletionTombstone: true,
                deletedAt: deletedAt,
                deletedByHumanId: "",
                lastModifiedAt: deletedAt,
                lastSyncedAt: Date(),
                createdAt: matchedState?.createdAt ?? deletedAt,
                updatedAt: Date()
            ),
            context: context
        )
        _ = state
        return .deleted(entityName: descriptor.entityName, localRecordId: localRecordId)
    }

    private static func supportsApply(for entityName: String) -> Bool {
        CloudSyncEntityRegistry.supportsUploadPipeline(for: entityName)
    }

    private static func rehydrateApplyResult(
        inserted: Bool,
        didPersist: Bool,
        localRecordUUID: UUID? = nil,
        metadata: RemoteMetadata
    ) -> CloudSyncRecordApplyResult {
        guard didPersist else {
            return .skippedUnsupported(entityName: metadata.entityName)
        }
        let localRecordId = CloudSyncRecordState.normalizedRecordId(localRecordUUID ?? metadata.localRecordUUID)
        return inserted
            ? .inserted(entityName: metadata.entityName, localRecordId: localRecordId)
            : .updated(entityName: metadata.entityName, localRecordId: localRecordId)
    }

    private static func applyLiveRecord(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        descriptor: CloudSyncEntityDescriptor,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyOutcome {
        switch descriptor.entityName {
        case String(describing: Household.self):
            CloudSyncRecordApplyOutcome(result: try applyHousehold(record, metadata: metadata, context: context))
        case String(describing: Pet.self):
            CloudSyncRecordApplyOutcome(result: try applyPet(record, metadata: metadata, context: context))
        case String(describing: Human.self):
            CloudSyncRecordApplyOutcome(result: try applyHuman(record, metadata: metadata, context: context))
        case String(describing: Event.self):
            try applyEvent(record, metadata: metadata, context: context)
        case String(describing: PetCareLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetCareLog(record, metadata: metadata, context: context))
        case String(describing: PetPottyLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetPottyLog(record, metadata: metadata, context: context))
        case String(describing: PetHygieneLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetHygieneLog(record, metadata: metadata, context: context))
        case String(describing: PetHealthLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetHealthLog(record, metadata: metadata, context: context))
        case String(describing: PetWalkLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetWalkLog(record, metadata: metadata, context: context))
        case String(describing: PetExpenseLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetExpenseLog(record, metadata: metadata, context: context))
        case String(describing: PetFoodRecord.self):
            CloudSyncRecordApplyOutcome(result: try applyPetFoodRecord(record, metadata: metadata, context: context))
        case String(describing: PetWeightLog.self):
            CloudSyncRecordApplyOutcome(result: try applyPetWeightLog(record, metadata: metadata, context: context))
        case String(describing: SharedCareSession.self):
            CloudSyncRecordApplyOutcome(result: try applySharedCareSession(record, metadata: metadata, context: context))
        case String(describing: CareLedgerEvent.self):
            CloudSyncRecordApplyOutcome(result: try applyCareLedgerEvent(record, metadata: metadata, context: context))
        case String(describing: CoconutLedgerEntry.self):
            CloudSyncRecordApplyOutcome(result: try applyCoconutLedgerEntry(record, metadata: metadata, context: context))
        case String(describing: GachaOwnedItem.self):
            try applyGachaOwnedItem(record, metadata: metadata, context: context)
        case String(describing: GachaDrawLog.self):
            CloudSyncRecordApplyOutcome(result: try applyGachaDrawLog(record, metadata: metadata, context: context))
        case String(describing: ShopPurchaseRecord.self):
            CloudSyncRecordApplyOutcome(result: try applyShopPurchaseRecord(record, metadata: metadata, context: context))
        default:
            CloudSyncRecordApplyOutcome(result: .skippedUnsupported(entityName: descriptor.entityName))
        }
    }

    private static func applyHousehold(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existing = try fetchHousehold(id: metadata.localRecordUUID, context: context)
        let result = try DomainGeneralRehydrateWriter.upsertHousehold(
            snapshot: DomainHouseholdRehydrateSnapshot(
                id: metadata.localRecordUUID,
                name: record.string(for: "name") ?? existing?.name ?? "",
                createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt,
                totalProsperity: record.int(for: "totalProsperity") ?? existing?.totalProsperity ?? 0
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPet(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existing = try fetchPet(id: metadata.localRecordUUID, context: context)
        let result = try DomainGeneralRehydrateWriter.upsertPet(
            snapshot: DomainPetRehydrateSnapshot(
                id: metadata.localRecordUUID,
                name: record.string(for: "name") ?? existing?.name ?? "",
                species: record.string(for: "species") ?? existing?.species ?? "狗",
                breed: record.string(for: "breed") ?? existing?.breed ?? "",
                birthday: record.date(for: "birthday"),
                gender: record.string(for: "gender") ?? existing?.gender ?? "unknown",
                isNeutered: record.bool(for: "isNeutered") ?? existing?.isNeutered ?? false,
                avatarEmoji: record.string(for: "avatarEmoji") ?? existing?.avatarEmoji ?? "🐾",
                avatarImageData: record.assetData(for: "avatarImageData"),
                microchipID: record.string(for: "microchipID") ?? existing?.microchipID ?? "",
                vetContact: record.string(for: "vetContact") ?? existing?.vetContact ?? "",
                vetClinicName: record.string(for: "vetClinicName") ?? existing?.vetClinicName ?? "",
                vetDoctorName: record.string(for: "vetDoctorName") ?? existing?.vetDoctorName ?? "",
                vetAddress: record.string(for: "vetAddress") ?? existing?.vetAddress ?? "",
                allergies: record.string(for: "allergies") ?? existing?.allergies ?? "",
                passportNumber: record.string(for: "passportNumber") ?? existing?.passportNumber ?? "",
                passportExpiryDate: record.date(for: "passportExpiryDate"),
                formerName: record.string(for: "formerName") ?? existing?.formerName ?? "",
                lineageInfo: record.string(for: "lineageInfo") ?? existing?.lineageInfo ?? "",
                themeColorHex: record.string(for: "themeColorHex") ?? existing?.themeColorHex ?? OhanaThemeColorPolicy.petFallbackHex,
                homeDate: record.date(for: "homeDate"),
                birthCountry: record.string(for: "birthCountry") ?? existing?.birthCountry ?? "",
                birthCity: record.string(for: "birthCity") ?? existing?.birthCity ?? "",
                foodBrand: record.string(for: "foodBrand") ?? existing?.foodBrand ?? "",
                restockDate: record.date(for: "restockDate"),
                restockWeight: record.double(for: "restockWeight") ?? existing?.restockWeight ?? 0,
                dailyPortionGrams: record.double(for: "dailyPortionGrams") ?? existing?.dailyPortionGrams ?? 0,
                mainFoodKindRaw: record.string(for: "mainFoodKindRaw") ?? existing?.mainFoodKindRaw ?? FeedFoodKind.dry.rawValue,
                foodPrice: record.double(for: "foodPrice") ?? existing?.foodPrice ?? 0,
                isShared: record.bool(for: "isShared") ?? existing?.isShared ?? false,
                ckRecordName: record.recordID.recordName,
                createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt,
                notes: record.string(for: "notes") ?? existing?.notes ?? "",
                coatColor: record.string(for: "coatColor") ?? existing?.coatColor ?? "",
                eyeColor: record.string(for: "eyeColor") ?? existing?.eyeColor ?? "",
                currentStreak: record.int(for: "currentStreak") ?? existing?.currentStreak ?? 0,
                lastCheckInDate: record.date(for: "lastCheckInDate"),
                foodTrackingModeRaw: record.string(for: "foodTrackingModeRaw") ?? existing?.foodTrackingModeRaw ?? FoodTrackingMode.casual.rawValue,
                casualOpenDate: record.date(for: "casualOpenDate"),
                casualDurationDays: record.int(for: "casualDurationDays") ?? existing?.casualDurationDays ?? 0,
                foodReminderEnabled: record.bool(for: "foodReminderEnabled") ?? existing?.foodReminderEnabled ?? false,
                foodReminderAdvanceDays: record.int(for: "foodReminderAdvanceDays") ?? existing?.foodReminderAdvanceDays ?? 7,
                coconutBalance: existing?.coconutBalance ?? 0,
                passedAwayDate: record.date(for: "passedAwayDate"),
                cardStyleRaw: record.string(for: "cardStyleRaw") ?? existing?.cardStyleRaw ?? "classic",
                cardPopoutImageData: record.assetData(for: "cardPopoutImageData"),
                cardPopoutSourceRaw: record.string(for: "cardPopoutSourceRaw"),
                weeklyWalkGoalKm: record.double(for: "weeklyWalkGoalKm") ?? existing?.weeklyWalkGoalKm ?? 0,
                personalityTagsRaw: record.string(for: "personalityTagsRaw") ?? existing?.personalityTagsRaw ?? ""
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyHuman(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existing = try fetchHuman(id: metadata.localRecordUUID, context: context)
        let result = try DomainGeneralRehydrateWriter.upsertHuman(
            snapshot: DomainHumanRehydrateSnapshot(
                id: metadata.localRecordUUID,
                name: record.string(for: "name") ?? existing?.name ?? "",
                birthday: record.date(for: "birthday"),
                bloodType: record.string(for: "bloodType") ?? existing?.bloodType ?? "",
                avatarEmoji: record.string(for: "avatarEmoji") ?? existing?.avatarEmoji ?? "👤",
                avatarImageData: record.assetData(for: "avatarImageData"),
                role: record.string(for: "role") ?? existing?.role ?? "member",
                genderIdentityRaw: record.string(for: "genderIdentityRaw"),
                notes: record.string(for: "notes") ?? existing?.notes ?? "",
                createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt,
                nationality: record.string(for: "nationality") ?? existing?.nationality ?? "",
                city: record.string(for: "city") ?? existing?.city ?? "",
                coconutBalance: existing?.coconutBalance ?? 0,
                shouldShowOnHome: record.bool(for: "shouldShowOnHome") ?? existing?.shouldShowOnHome ?? true,
                mbti: record.string(for: "mbti") ?? existing?.mbti ?? "",
                privateFieldsRaw: record.string(for: "privateFieldsRaw") ?? existing?.privateFieldsRaw ?? "",
                themeColorHex: record.string(for: "themeColorHex") ?? existing?.themeColorHex ?? OhanaThemeColorPolicy.humanFallbackHex,
                heightCm: record.double(for: "heightCm") ?? existing?.heightCm ?? 0,
                passedAwayDate: record.date(for: "passedAwayDate")
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyEvent(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyOutcome {
        let existing = try fetchEvent(id: metadata.localRecordUUID, context: context)
        let snapshot = DomainScheduleRehydrateEventSnapshot(
            id: metadata.localRecordUUID,
            title: record.string(for: "title") ?? existing?.title ?? "",
            startDate: record.date(for: "startDate") ?? existing?.startDate ?? metadata.lastModifiedAt,
            endDate: record.date(for: "endDate"),
            isAllDay: record.bool(for: "isAllDay") ?? existing?.isAllDay ?? false,
            eventType: record.string(for: "eventType") ?? existing?.eventType ?? EventType.daily.rawValue,
            relatedEntityType: record.string(for: "relatedEntityType") ?? existing?.relatedEntityType ?? "",
            relatedEntityId: record.string(for: "relatedEntityId") ?? existing?.relatedEntityId ?? "",
            recurrenceDays: record.int(for: "recurrenceDays") ?? existing?.recurrenceDays ?? 0,
            recurrenceEndDate: record.date(for: "recurrenceEndDate"),
            isCompleted: record.bool(for: "isCompleted") ?? existing?.isCompleted ?? false,
            completedOccurrences: record.stringList(for: "completedOccurrences") ?? existing?.completedOccurrences ?? [],
            createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt,
            assigneeId: record.string(for: "assigneeId"),
            feedRuleKindRaw: record.string(for: "feedRuleKindRaw") ?? existing?.feedRuleKindRaw ?? "",
            foodKindRaw: record.string(for: "foodKindRaw") ?? existing?.foodKindRaw ?? FeedFoodKind.dry.rawValue,
            feedAmountGrams: record.double(for: "feedAmountGrams") ?? existing?.feedAmountGrams ?? 0,
            feedPlanGroupId: record.string(for: "feedPlanGroupId") ?? existing?.feedPlanGroupId ?? ""
        )
        let result = try DomainScheduleRehydrateWriter.upsertEvent(
            snapshot: snapshot,
            source: .cloudApply,
            context: context
        )
        guard result.event != nil else {
            return CloudSyncRecordApplyOutcome(result: .skippedUnsupported(entityName: metadata.entityName))
        }
        let applyResult: CloudSyncRecordApplyResult = result.inserted
            ? .inserted(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
            : .updated(entityName: metadata.entityName, localRecordId: metadata.localRecordId)
        return CloudSyncRecordApplyOutcome(
            result: applyResult,
            notificationIdsToCancel: result.notificationIdsToCancel
        )
    }

    private static func applyPetCareLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetCareLogIfNeeded(
            snapshot: DomainPetCareLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                typeRaw: record.string(for: "type") ?? CareType.feeding.rawValue,
                amountGrams: record.double(for: "amountGrams") ?? 0,
                amountMl: record.double(for: "amountMl") ?? 0,
                note: record.string(for: "note") ?? "",
                foodKindRaw: record.string(for: "foodKindRaw") ?? FeedFoodKind.dry.rawValue,
                treatKindRaw: record.string(for: "treatKindRaw"),
                autoFeedDedupKey: record.string(for: "autoFeedDedupKey") ?? "",
                sharedSessionId: record.string(for: "sharedSessionId") ?? "",
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId")
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetPottyLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetPottyLogIfNeeded(
            snapshot: DomainPetPottyLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                typeRaw: record.string(for: "type") ?? PottyType.perfectPoop.rawValue,
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId"),
                latitude: record.double(for: "latitude"),
                longitude: record.double(for: "longitude"),
                locationAccuracyMeters: record.double(for: "locationAccuracyMeters"),
                walkLogId: record.string(for: "walkLogId"),
                sharedSessionId: record.string(for: "sharedSessionId") ?? ""
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetHygieneLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetHygieneLogIfNeeded(
            snapshot: DomainPetHygieneLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                typeRaw: record.string(for: "type") ?? HygieneType.bath.rawValue,
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId"),
                sharedSessionId: record.string(for: "sharedSessionId") ?? ""
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetHealthLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetHealthLogIfNeeded(
            snapshot: DomainPetHealthLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                typeRaw: record.string(for: "type") ?? HealthLogType.general.rawValue,
                note: record.string(for: "note") ?? "",
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId"),
                vetName: record.string(for: "vetName") ?? "",
                cost: record.double(for: "cost") ?? 0,
                expirationDate: record.date(for: "expirationDate"),
                nextCheckupDate: record.date(for: "nextCheckupDate")
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetWalkLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetWalkLogIfNeeded(
            snapshot: DomainPetWalkLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                startDate: record.date(for: "startDate") ?? metadata.lastModifiedAt,
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId"),
                executorIdsRaw: record.string(for: "executorIdsRaw") ?? "",
                sharedSessionId: record.string(for: "sharedSessionId") ?? "",
                endDate: record.date(for: "endDate"),
                distanceMeters: record.double(for: "distanceMeters") ?? 0,
                coconutsEarned: record.int(for: "coconutsEarned") ?? 0,
                mapSnapshotData: record.assetData(for: "mapSnapshotData"),
                routeLocationsData: record.assetData(for: "routeLocationsData"),
                behaviorNotes: record.string(for: "behaviorNotes"),
                moodRating: record.int(for: "moodRating") ?? 0
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetExpenseLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
            snapshot: DomainPetExpenseLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                amount: record.double(for: "amount") ?? 0,
                categoryRaw: record.string(for: "category") ?? ExpenseCategory.other.rawValue,
                note: record.string(for: "note") ?? "",
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId"),
                sharedSessionId: record.string(for: "sharedSessionId") ?? ""
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetFoodRecord(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existing = try fetchPetFoodRecord(id: metadata.localRecordUUID, context: context)
        let result = try DomainCareFactRehydrateWriter.upsertPetFoodRecord(
            snapshot: DomainPetFoodRecordRehydrateSnapshot(
                id: metadata.localRecordUUID,
                brand: record.string(for: "brand") ?? existing?.brand ?? "",
                dailyGrams: record.double(for: "dailyGrams") ?? existing?.dailyGrams ?? 0,
                totalGrams: record.double(for: "totalGrams") ?? existing?.totalGrams ?? 0,
                foodKindRaw: record.string(for: "foodKindRaw") ?? existing?.foodKindRaw ?? FeedFoodKind.dry.rawValue,
                purchaseDate: record.date(for: "purchaseDate"),
                startDate: record.date(for: "startDate") ?? existing?.startDate ?? metadata.lastModifiedAt,
                remainingCorrectionGrams: record.double(for: "remainingCorrectionGrams"),
                remainingCorrectionDate: record.date(for: "remainingCorrectionDate"),
                notes: record.string(for: "notes") ?? existing?.notes ?? "",
                expenseId: record.string(for: "expenseId").flatMap(UUID.init(uuidString:)),
                calculationModeRaw: record.string(for: "calculationModeRaw") ?? existing?.calculationModeRaw ?? FeedStockCalculationMode.manualOrPlan.rawValue,
                executorId: record.string(for: "executorId"),
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:))
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyPetWeightLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertPetWeightLogIfNeeded(
            snapshot: DomainPetWeightLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                weight: record.double(for: "weight") ?? 0,
                weightUnit: record.string(for: "weightUnit") ?? "kg",
                bcsScore: record.int(for: "bcsScore") ?? 0,
                petId: record.string(for: "petId").flatMap(UUID.init(uuidString:)),
                executorId: record.string(for: "executorId")
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applySharedCareSession(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainCareFactRehydrateWriter.insertSharedCareSessionIfNeeded(
            snapshot: DomainSharedCareSessionRehydrateSnapshot(
                id: metadata.localRecordUUID,
                date: record.date(for: "date") ?? metadata.lastModifiedAt,
                actionKindRaw: record.string(for: "actionKindRaw") ?? SharedCareActionKind.feeding.rawValue,
                executorId: record.string(for: "executorId"),
                executorIdsRaw: record.string(for: "executorIdsRaw") ?? "",
                sourcePetId: record.string(for: "sourcePetId") ?? "",
                targetPetIds: (record.string(for: "targetPetIdsRaw") ?? "").split(separator: "|").map(String.init),
                speciesRaw: record.string(for: "speciesRaw") ?? "",
                totalAmountGrams: record.double(for: "totalAmountGrams") ?? 0,
                totalAmountMl: record.double(for: "totalAmountMl") ?? 0,
                totalExpenseAmount: record.double(for: "totalExpenseAmount") ?? 0,
                expenseCategoryRaw: record.string(for: "expenseCategoryRaw") ?? ExpenseCategory.other.rawValue,
                currencyCode: record.string(for: "currencyCode") ?? "",
                allocationModeRaw: record.string(for: "allocationModeRaw") ?? SharedCareAllocationMode.equal.rawValue,
                foodKindRaw: record.string(for: "foodKindRaw") ?? FeedFoodKind.dry.rawValue,
                stockOwnerPetId: record.string(for: "stockOwnerPetId") ?? "",
                primaryLegacyModelName: record.string(for: "primaryLegacyModelName") ?? "",
                primaryLegacyModelId: record.string(for: "primaryLegacyModelId") ?? "",
                note: record.string(for: "note") ?? "",
                createdAt: record.date(for: "createdAt") ?? metadata.lastModifiedAt
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyCareLedgerEvent(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existing = try fetchCareLedgerEvent(id: metadata.localRecordUUID, context: context)
        let snapshot = DomainCareLedgerRehydrateSnapshot(
            id: metadata.localRecordUUID,
            occurredAt: record.date(for: "occurredAt") ?? existing?.occurredAt ?? metadata.lastModifiedAt,
            actorKind: record.string(for: "actorKind") ?? existing?.actorKind ?? CareLedgerActorKind.unknown.rawValue,
            actorId: record.string(for: "actorId"),
            subjectKind: record.string(for: "subjectKind") ?? existing?.subjectKind ?? CareLedgerSubjectKind.unknown.rawValue,
            subjectId: record.string(for: "subjectId"),
            eventKind: record.string(for: "eventKind") ?? existing?.eventKind ?? CareLedgerEventKind.unknown.rawValue,
            actionType: record.string(for: "actionType") ?? existing?.actionType ?? "",
            amountValue: record.double(for: "amountValue") ?? existing?.amountValue ?? 0,
            amountUnit: record.string(for: "amountUnit") ?? existing?.amountUnit ?? "",
            note: record.string(for: "note") ?? existing?.note ?? "",
            source: record.string(for: "source") ?? existing?.source ?? CareLedgerSource.service.rawValue,
            sourceEventId: record.string(for: "sourceEventId"),
            sourceReminderId: record.string(for: "sourceReminderId"),
            legacyModelName: record.string(for: "legacyModelName"),
            legacyModelId: record.string(for: "legacyModelId"),
            coconutDelta: record.int(for: "coconutDelta") ?? existing?.coconutDelta ?? 0,
            rewardLogId: record.string(for: "rewardLogId"),
            privacyFieldRaw: record.string(for: "privacyFieldRaw"),
            metadataJSON: record.string(for: "metadataJSON") ?? existing?.metadataJSON ?? "",
            createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt
        )
        let result = try DomainCareLedgerRehydrateWriter.upsertCareLedgerEvent(
            snapshot: snapshot,
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyCoconutLedgerEntry(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let result = try DomainGeneralRehydrateWriter.upsertCoconutLedgerEntry(
            snapshot: DomainCoconutLedgerEntryRehydrateSnapshot(
                id: metadata.localRecordUUID,
                transactionKey: record.string(for: "transactionKey") ?? metadata.recordKey,
                accountKey: record.string(for: "accountKey") ?? "system:legacy",
                ownerKindRaw: record.string(for: "ownerKindRaw") ?? CoconutWalletOwnerKind.system.rawValue,
                ownerId: record.string(for: "ownerId") ?? "",
                ownerName: record.string(for: "ownerName") ?? "",
                delta: record.int(for: "delta") ?? 0,
                balanceBefore: record.int(for: "balanceBefore") ?? 0,
                balanceAfter: record.int(for: "balanceAfter") ?? 0,
                affectsBalance: record.bool(for: "affectsBalance") ?? true,
                entryKindRaw: record.string(for: "entryKindRaw") ?? CoconutWalletEntryKind.adjustment.rawValue,
                sourceRaw: record.string(for: "sourceRaw") ?? CoconutWalletSource.service.rawValue,
                title: record.string(for: "title") ?? "",
                emoji: record.string(for: "emoji") ?? "",
                actorId: record.string(for: "actorId"),
                actorName: record.string(for: "actorName"),
                subjectKindRaw: record.string(for: "subjectKindRaw") ?? CareLedgerSubjectKind.system.rawValue,
                subjectId: record.string(for: "subjectId"),
                sourceModelName: record.string(for: "sourceModelName") ?? "",
                sourceModelId: record.string(for: "sourceModelId") ?? "",
                careLedgerEventId: record.string(for: "careLedgerEventId"),
                metadataJSON: record.string(for: "metadataJSON") ?? "",
                occurredAt: record.date(for: "occurredAt") ?? metadata.lastModifiedAt,
                createdAt: record.date(for: "createdAt") ?? metadata.lastModifiedAt
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyGachaOwnedItem(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyOutcome {
        let existing = try fetchGachaOwnedItem(id: metadata.localRecordUUID, context: context)
        let result = try DomainGeneralRehydrateWriter.upsertGachaOwnedItem(
            snapshot: DomainGachaOwnedItemRehydrateSnapshot(
                id: metadata.localRecordUUID,
                ownerHumanId: record.string(for: "ownerHumanId") ?? existing?.ownerHumanId ?? "",
                seriesId: record.string(for: "seriesId") ?? existing?.seriesId ?? "",
                itemId: record.string(for: "itemId") ?? existing?.itemId ?? "",
                rarityRaw: record.string(for: "rarityRaw") ?? existing?.rarityRaw ?? GachaRarity.common.rawValue,
                isHidden: record.bool(for: "isHidden") ?? existing?.isHidden ?? false,
                ownedCount: record.int(for: "ownedCount") ?? existing?.ownedCount ?? 1,
                firstObtainedAt: record.date(for: "firstObtainedAt") ?? existing?.firstObtainedAt ?? metadata.lastModifiedAt,
                latestObtainedAt: record.date(for: "latestObtainedAt") ?? existing?.latestObtainedAt ?? metadata.lastModifiedAt,
                createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt
            ),
            source: .cloudApply,
            context: context
        )
        let appliedLocalRecordUUID = result.model?.id
        return CloudSyncRecordApplyOutcome(
            result: rehydrateApplyResult(
                inserted: result.inserted,
                didPersist: result.didPersist,
                localRecordUUID: appliedLocalRecordUUID,
                metadata: metadata
            ),
            stateLocalRecordUUID: result.didPersist ? appliedLocalRecordUUID : nil
        )
    }

    private static func applyGachaDrawLog(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existing = try fetchGachaDrawLog(id: metadata.localRecordUUID, context: context)
        let result = try DomainGeneralRehydrateWriter.upsertGachaDrawLog(
            snapshot: DomainGachaDrawLogRehydrateSnapshot(
                id: metadata.localRecordUUID,
                ownerHumanId: record.string(for: "ownerHumanId") ?? existing?.ownerHumanId ?? "",
                ownerName: record.string(for: "ownerName") ?? existing?.ownerName ?? "",
                seriesId: record.string(for: "seriesId") ?? existing?.seriesId ?? "",
                itemId: record.string(for: "itemId") ?? existing?.itemId ?? "",
                rarityRaw: record.string(for: "rarityRaw") ?? existing?.rarityRaw ?? GachaRarity.common.rawValue,
                isHidden: record.bool(for: "isHidden") ?? existing?.isHidden ?? false,
                isNew: record.bool(for: "isNew") ?? existing?.isNew ?? false,
                outcomeKindRaw: record.string(for: "outcomeKindRaw") ?? existing?.outcomeKindRaw ?? GachaOutcomeKind.collectible.rawValue,
                instantResultId: record.string(for: "instantResultId") ?? existing?.instantResultId ?? "",
                instantTitleZh: record.string(for: "instantTitleZh") ?? existing?.instantTitleZh ?? "",
                instantTitleEn: record.string(for: "instantTitleEn") ?? existing?.instantTitleEn ?? "",
                instantTitleDe: record.string(for: "instantTitleDe") ?? existing?.instantTitleDe ?? "",
                instantDetailZh: record.string(for: "instantDetailZh") ?? existing?.instantDetailZh ?? "",
                instantDetailEn: record.string(for: "instantDetailEn") ?? existing?.instantDetailEn ?? "",
                instantDetailDe: record.string(for: "instantDetailDe") ?? existing?.instantDetailDe ?? "",
                instantSymbol: record.string(for: "instantSymbol") ?? existing?.instantSymbol ?? "",
                instantCoconutDelta: record.int(for: "instantCoconutDelta") ?? existing?.instantCoconutDelta ?? 0,
                costCoconuts: record.int(for: "costCoconuts") ?? existing?.costCoconuts ?? DomainGachaDrawDefaults.costPerDraw,
                dailySequence: record.int(for: "dailySequence") ?? existing?.dailySequence ?? 1,
                drawDate: record.date(for: "drawDate") ?? existing?.drawDate ?? metadata.lastModifiedAt,
                createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func applyShopPurchaseRecord(
        _ record: CKRecord,
        metadata: RemoteMetadata,
        context: ModelContext
    ) throws -> CloudSyncRecordApplyResult {
        let existingById = try fetchShopPurchaseRecord(id: metadata.localRecordUUID, context: context)
        let existingByTransactionKey = try fetchShopPurchaseRecord(
            transactionKey: record.string(for: "transactionKey") ?? "",
            context: context
        )
        let existing = existingById ?? existingByTransactionKey
        let result = try DomainGeneralRehydrateWriter.upsertShopPurchaseRecord(
            snapshot: DomainShopPurchaseRecordRehydrateSnapshot(
                id: metadata.localRecordUUID,
                transactionKey: record.string(for: "transactionKey") ?? existing?.transactionKey ?? metadata.recordKey,
                itemId: record.string(for: "itemId") ?? existing?.itemId ?? "",
                buyerHumanId: record.string(for: "buyerHumanId") ?? existing?.buyerHumanId ?? "",
                purchasedAt: record.date(for: "purchasedAt") ?? existing?.purchasedAt ?? metadata.lastModifiedAt,
                sourceRaw: record.string(for: "sourceRaw") ?? existing?.sourceRaw ?? "shop",
                isLegacyImport: record.bool(for: "isLegacyImport") ?? existing?.isLegacyImport ?? false,
                createdAt: record.date(for: "createdAt") ?? existing?.createdAt ?? metadata.lastModifiedAt
            ),
            source: .cloudApply,
            context: context
        )
        return rehydrateApplyResult(inserted: result.inserted, didPersist: result.didPersist, metadata: metadata)
    }

    private static func upsertState(
        metadata: RemoteMetadata,
        record: CKRecord,
        context: ModelContext,
        localRecordUUID: UUID? = nil
    ) throws -> CloudSyncRecordState {
        let stateLocalRecordUUID = localRecordUUID ?? metadata.localRecordUUID
        let stateRecordKey = stateLocalRecordUUID == metadata.localRecordUUID
            ? metadata.recordKey
            : CloudSyncRecordState.recordKey(
                entityName: metadata.entityName,
                localRecordId: stateLocalRecordUUID
            )
        return try CloudSyncMetadataService.upsertAppliedRemoteState(
            snapshot: CloudSyncAppliedRecordStateSnapshot(
                recordKey: stateRecordKey,
                entityName: metadata.entityName,
                localRecordId: stateLocalRecordUUID,
                householdId: metadata.householdUUID,
                ckZoneName: record.recordID.zoneID.zoneName,
                ckRecordName: record.recordID.recordName,
                ckChangeTag: record.recordChangeTag ?? "",
                conflictPolicy: metadata.conflictPolicy,
                isDeleted: metadata.isDeleted,
                isDeletionTombstone: metadata.isDeleted,
                deletedAt: metadata.deletedAt,
                deletedByHumanId: metadata.deletedByHumanId,
                lastModifiedAt: metadata.lastModifiedAt,
                lastSyncedAt: nil,
                createdAt: metadata.lastModifiedAt,
                updatedAt: Date()
            ),
            context: context
        )
    }

    private static func existingAppliedState(
        metadata: RemoteMetadata,
        record: CKRecord,
        context: ModelContext
    ) throws -> CloudSyncRecordState? {
        if let state = try CloudSyncMetadataService.state(recordKey: metadata.recordKey, context: context) {
            return state
        }
        return try CloudSyncMetadataService.state(
            entityName: metadata.entityName,
            ckRecordName: record.recordID.recordName,
            ckZoneName: record.recordID.zoneID.zoneName,
            context: context
        )
    }

    private static func localRecordUUID(from state: CloudSyncRecordState?) -> UUID? {
        guard let state else { return nil }
        return UUID(uuidString: state.localRecordId)
    }

    private static func deleteLocalModel(metadata: RemoteMetadata, context: ModelContext) throws {
        try deleteLocalModel(
            entityName: metadata.entityName,
            localRecordUUID: metadata.localRecordUUID,
            deletedAt: metadata.deletedAt ?? metadata.lastModifiedAt,
            deletedByHumanId: normalizedDeletionActorId(metadata.deletedByHumanId),
            context: context
        )
    }

    private static func deleteLocalModel(
        entityName: String,
        localRecordUUID: UUID,
        deletedAt: Date,
        deletedByHumanId: String?,
        context: ModelContext
    ) throws {
        switch entityName {
        case String(describing: Household.self):
            try deleteHousehold(id: localRecordUUID, context: context)
        case String(describing: Pet.self):
            if let model = try fetchPet(id: localRecordUUID, context: context) {
                PhysicalDeletionService.deletePet(
                    model,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: Human.self):
            if let model = try fetchHuman(id: localRecordUUID, context: context) {
                PhysicalDeletionService.deleteHuman(
                    model,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: Event.self):
            if let model = try fetchEvent(id: localRecordUUID, context: context) {
                PhysicalDeletionService.deleteEvent(
                    model,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetCareLog.self):
            if let model = try fetchPetCareLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetPottyLog.self):
            if let model = try fetchPetPottyLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetHygieneLog.self):
            if let model = try fetchPetHygieneLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetHealthLog.self):
            if let model = try fetchPetHealthLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetWalkLog.self):
            if let model = try fetchPetWalkLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetExpenseLog.self):
            if let model = try fetchPetExpenseLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetFoodRecord.self):
            if let model = try fetchPetFoodRecord(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: PetWeightLog.self):
            if let model = try fetchPetWeightLog(id: localRecordUUID, context: context) {
                deletePetScopedRecord(
                    model,
                    pet: model.pet,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
            }
        case String(describing: SharedCareSession.self):
            if let model = try fetchSharedCareSession(id: localRecordUUID, context: context) {
                try SharedCareSessionMaintenance.deleteCascade(
                    model,
                    context: context,
                    deletedByHumanId: deletedByHumanId,
                    deletedAt: deletedAt
                )
            }
        case String(describing: CareLedgerEvent.self):
            try deleteCareLedgerEvent(id: localRecordUUID, context: context)
        case String(describing: CoconutLedgerEntry.self):
            // CoconutLedgerEntry is append-only. A remote tombstone should mark
            // sync state only; removing local history would corrupt replay and
            // make balances jump without an explicit reversal entry.
            break
        case String(describing: GachaOwnedItem.self):
            try deleteGachaOwnedItem(id: localRecordUUID, context: context)
        case String(describing: GachaDrawLog.self):
            try deleteGachaDrawLog(id: localRecordUUID, context: context)
        case String(describing: ShopPurchaseRecord.self):
            try deleteShopPurchaseRecord(id: localRecordUUID, context: context)
        default:
            break
        }
    }

    private static func deleteHousehold(id: UUID, context: ModelContext) throws {
        if let model = try fetchHousehold(id: id, context: context) {
            context.delete(model)
        }
    }

    private static func deleteCareLedgerEvent(id: UUID, context: ModelContext) throws {
        if let model = try fetchCareLedgerEvent(id: id, context: context) {
            context.delete(model)
        }
    }

    private static func deleteGachaOwnedItem(id: UUID, context: ModelContext) throws {
        if let model = try fetchGachaOwnedItem(id: id, context: context) {
            context.delete(model)
        }
    }

    private static func deleteGachaDrawLog(id: UUID, context: ModelContext) throws {
        if let model = try fetchGachaDrawLog(id: id, context: context) {
            context.delete(model)
        }
    }

    private static func deleteShopPurchaseRecord(id: UUID, context: ModelContext) throws {
        if let model = try fetchShopPurchaseRecord(id: id, context: context) {
            context.delete(model)
        }
    }

    private static func deletePetScopedRecord(
        _ model: any PersistentModel,
        pet: Pet?,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        let stockReminderPets = stockReminderPetsAffectedByDeleting(model, fallbackPet: pet)
        let didDelete = PhysicalDeletionService.deletePetScopedRecord(
            model,
            pet: pet,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId
        )
        guard didDelete, !stockReminderPets.isEmpty else { return }
        guard saveCloudSyncDeletionChanges(context: context) else { return }
        FeedingPlanWriter.rebuildFoodStockReminders(
            pets: stockReminderPets,
            context: context,
            now: deletedAt
        )
    }

    private static func stockReminderPetsAffectedByDeleting(_ model: any PersistentModel, fallbackPet: Pet?) -> [Pet] {
        switch model {
        case let log as PetCareLog where log.careType == .feeding:
            (log.pet ?? fallbackPet).map { [$0] } ?? []
        case let record as PetFoodRecord:
            (record.pet ?? fallbackPet).map { [$0] } ?? []
        default:
            []
        }
    }

    private static func normalizedDeletionActorId(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private static func fetchEvent(id: UUID, context: ModelContext) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.id == id }
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

    private static func fetchPetFoodRecord(id: UUID, context: ModelContext) throws -> PetFoodRecord? {
        var descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { $0.id == id }
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

    private static func fetchGachaOwnedItem(id: UUID, context: ModelContext) throws -> GachaOwnedItem? {
        var descriptor = FetchDescriptor<GachaOwnedItem>(
            predicate: #Predicate<GachaOwnedItem> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchGachaDrawLog(id: UUID, context: ModelContext) throws -> GachaDrawLog? {
        var descriptor = FetchDescriptor<GachaDrawLog>(
            predicate: #Predicate<GachaDrawLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchShopPurchaseRecord(id: UUID, context: ModelContext) throws -> ShopPurchaseRecord? {
        var descriptor = FetchDescriptor<ShopPurchaseRecord>(
            predicate: #Predicate<ShopPurchaseRecord> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchShopPurchaseRecord(transactionKey: String, context: ModelContext) throws -> ShopPurchaseRecord? {
        guard !transactionKey.isEmpty else { return nil }
        var descriptor = FetchDescriptor<ShopPurchaseRecord>(
            predicate: #Predicate<ShopPurchaseRecord> { $0.transactionKey == transactionKey }
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

    private static func saveCloudSyncApplyChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw CloudSyncRecordApplyPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @discardableResult
    private static func saveCloudSyncDeletionChanges(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }
}

enum CloudSyncRecordApplyPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            message ?? String(
                localized: "cloud.sync.apply.persistence.failed",
                defaultValue: "Unable to save cloud sync changes.",
                comment: "Shown when applying a cloud sync record cannot be saved."
            )
        }
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

    nonisolated func stringList(for key: String) -> [String]? {
        if let value = self[key] as? [String] {
            return value
        }
        if let value = self[key] as? NSArray {
            return value.compactMap { $0 as? String }
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
