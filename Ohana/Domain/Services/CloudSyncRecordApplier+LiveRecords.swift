//
//  CloudSyncRecordApplier+LiveRecords.swift
//  Ohana
//
//  Split helpers for applying CloudKit records into SwiftData.
//

import CloudKit
import Foundation
import SwiftData

extension CloudSyncRecordApplier {
    private nonisolated static func rehydrateApplyResult(
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

    nonisolated static func applyLiveRecord(
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

    private nonisolated static func applyHousehold(
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

    private nonisolated static func applyPet(
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

    private nonisolated static func applyHuman(
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

    private nonisolated static func applyEvent(
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

    private nonisolated static func applyPetCareLog(
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

    private nonisolated static func applyPetPottyLog(
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

    private nonisolated static func applyPetHygieneLog(
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

    private nonisolated static func applyPetHealthLog(
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

    private nonisolated static func applyPetWalkLog(
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

    private nonisolated static func applyPetExpenseLog(
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

    private nonisolated static func applyPetFoodRecord(
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

    private nonisolated static func applyPetWeightLog(
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

    private nonisolated static func applySharedCareSession(
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

    private nonisolated static func applyCareLedgerEvent(
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

    private nonisolated static func applyCoconutLedgerEntry(
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

    private nonisolated static func applyGachaOwnedItem(
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

    private nonisolated static func applyGachaDrawLog(
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

    private nonisolated static func applyShopPurchaseRecord(
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
}
