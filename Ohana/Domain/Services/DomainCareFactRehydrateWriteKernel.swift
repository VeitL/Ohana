//
//  DomainCareFactRehydrateWriteKernel.swift
//  Ohana
//
//  Central rehydrate writer for care facts received from cloud/backup records.
//

import Foundation
import SwiftData

nonisolated struct DomainPetCareLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let typeRaw: String
    let amountGrams: Double
    let amountMl: Double
    let note: String
    let foodKindRaw: String
    let treatKindRaw: String?
    let autoFeedDedupKey: String
    let sharedSessionId: String
    let petId: UUID?
    let executorId: String?
}

nonisolated struct DomainPlantCareLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let careTypeRaw: String
    let note: String
    let executorId: String?
    let plantId: UUID?
    let healthStatusRaw: String
    let photoData: Data?
}

nonisolated struct DomainPetPottyLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let typeRaw: String
    let petId: UUID?
    let executorId: String?
    let latitude: Double?
    let longitude: Double?
    let locationAccuracyMeters: Double?
    let walkLogId: String?
    let sharedSessionId: String
}

nonisolated struct DomainPetHygieneLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let typeRaw: String
    let petId: UUID?
    let executorId: String?
    let sharedSessionId: String
}

nonisolated struct DomainPetHealthLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let typeRaw: String
    let note: String
    let petId: UUID?
    let executorId: String?
    let vetName: String
    let cost: Double
    let expirationDate: Date?
    let nextCheckupDate: Date?
}

nonisolated struct DomainPetWalkLogRehydrateSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let petId: UUID?
    let executorId: String?
    let executorIdsRaw: String
    let sharedSessionId: String
    let endDate: Date?
    let distanceMeters: Double
    let coconutsEarned: Int
    let mapSnapshotData: Data?
    let routeLocationsData: Data?
    let behaviorNotes: String?
    let moodRating: Int
}

nonisolated struct DomainPetExpenseLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let amount: Double
    let categoryRaw: String
    let note: String
    let petId: UUID?
    let executorId: String?
    let sharedSessionId: String
}

nonisolated struct DomainPetFoodRecordRehydrateSnapshot: Equatable {
    let id: UUID
    let brand: String
    let dailyGrams: Double
    let totalGrams: Double
    let foodKindRaw: String
    let purchaseDate: Date?
    let startDate: Date
    let remainingCorrectionGrams: Double?
    let remainingCorrectionDate: Date?
    let notes: String
    let expenseId: UUID?
    let calculationModeRaw: String
    let executorId: String?
    let petId: UUID?
}

nonisolated struct DomainPetWeightLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let weightUnit: String
    let bcsScore: Int
    let petId: UUID?
    let executorId: String?
}

nonisolated struct DomainSharedCareSessionRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let actionKindRaw: String
    let executorId: String?
    let executorIdsRaw: String
    let sourcePetId: String
    let targetPetIds: [String]
    let speciesRaw: String
    let totalAmountGrams: Double
    let totalAmountMl: Double
    let totalExpenseAmount: Double
    let expenseCategoryRaw: String
    let currencyCode: String
    let allocationModeRaw: String
    let foodKindRaw: String
    let stockOwnerPetId: String
    let primaryLegacyModelName: String
    let primaryLegacyModelId: String
    let note: String
    let createdAt: Date
}

nonisolated struct DomainCareFactRehydrateResult {
    let inserted: Bool
    let plan: AuthorizedDomainRehydratePlan

    var didPersist: Bool {
        plan.disposition.allowsPersistence
    }
}

nonisolated enum DomainCareFactRehydrateWriter {
    @discardableResult
    static func insertPlantCareLogIfNeeded(
        snapshot: DomainPlantCareLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = try authorizePlant(plantId: snapshot.plantId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPlantCareLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PlantCareLog(
            date: snapshot.date,
            careType: PlantCareType(rawValue: snapshot.careTypeRaw) ?? .customNote,
            note: snapshot.note,
            executorId: snapshot.executorId,
            photoData: snapshot.photoData,
            healthStatus: PlantHealthStatus(rawValue: snapshot.healthStatusRaw)
        )
        log.id = snapshot.id
        log.plant = try plantReference(id: snapshot.plantId, context: context)
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetCareLogIfNeeded(
        snapshot: DomainPetCareLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetCareLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetCareLog(
            date: snapshot.date,
            type: CareType(rawValue: snapshot.typeRaw) ?? .feeding,
            amountGrams: snapshot.amountGrams,
            amountMl: snapshot.amountMl,
            note: snapshot.note,
            foodKind: FeedFoodKind(rawValue: snapshot.foodKindRaw) ?? .dry,
            treatKind: snapshot.treatKindRaw.flatMap(FeedTreatKind.init(rawValue:)),
            autoFeedDedupKey: snapshot.autoFeedDedupKey,
            sharedSessionId: snapshot.sharedSessionId,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetPottyLogIfNeeded(
        snapshot: DomainPetPottyLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetPottyLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetPottyLog(
            date: snapshot.date,
            type: PottyType(rawValue: snapshot.typeRaw) ?? .perfectPoop,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            locationAccuracyMeters: snapshot.locationAccuracyMeters,
            walkLogId: snapshot.walkLogId,
            sharedSessionId: snapshot.sharedSessionId
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetHygieneLogIfNeeded(
        snapshot: DomainPetHygieneLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetHygieneLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetHygieneLog(
            date: snapshot.date,
            type: HygieneType(rawValue: snapshot.typeRaw) ?? .bath,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId,
            sharedSessionId: snapshot.sharedSessionId
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetHealthLogIfNeeded(
        snapshot: DomainPetHealthLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetHealthLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetHealthLog(
            date: snapshot.date,
            type: HealthLogType(rawValue: snapshot.typeRaw) ?? .general,
            note: snapshot.note,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId
        )
        log.id = snapshot.id
        log.vetName = snapshot.vetName
        log.cost = snapshot.cost
        log.expirationDate = snapshot.expirationDate
        log.nextCheckupDate = snapshot.nextCheckupDate
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetWalkLogIfNeeded(
        snapshot: DomainPetWalkLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetWalkLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetWalkLog(
            startDate: snapshot.startDate,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId,
            executorIds: SharedCareParticipantIDs.decode(
                snapshot.executorIdsRaw,
                fallback: snapshot.executorId
            ),
            sharedSessionId: snapshot.sharedSessionId
        )
        log.id = snapshot.id
        log.endDate = snapshot.endDate
        log.distanceMeters = snapshot.distanceMeters
        log.coconutsEarned = snapshot.coconutsEarned
        log.mapSnapshotData = snapshot.mapSnapshotData
        log.routeLocationsData = snapshot.routeLocationsData
        log.behaviorNotes = snapshot.behaviorNotes
        log.moodRating = snapshot.moodRating
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetExpenseLogIfNeeded(
        snapshot: DomainPetExpenseLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        try ExpenseAmountPolicy.validatePersistedExpense(
            amount: snapshot.amount,
            categoryRaw: snapshot.categoryRaw,
            note: snapshot.note
        )
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetExpenseLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        // economy-boundary: allow rehydrate preserves legacy expense facts without emitting new ledger effects.
        let log = PetExpenseLog(
            date: snapshot.date,
            amount: snapshot.amount,
            category: ExpenseCategory(rawValue: snapshot.categoryRaw) ?? .other,
            note: snapshot.note,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId,
            sharedSessionId: snapshot.sharedSessionId
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func upsertPetFoodRecord(
        snapshot: DomainPetFoodRecordRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        let foodRecord: PetFoodRecord
        let inserted: Bool
        if let existing = try fetchPetFoodRecord(id: snapshot.id, context: context) {
            foodRecord = existing
            inserted = false
        } else {
            foodRecord = PetFoodRecord(
                brand: snapshot.brand,
                dailyGrams: snapshot.dailyGrams,
                totalGrams: snapshot.totalGrams,
                foodKind: FeedFoodKind(rawValue: snapshot.foodKindRaw) ?? .dry,
                purchaseDate: snapshot.purchaseDate,
                startDate: snapshot.startDate,
                pet: try petReference(id: snapshot.petId, context: context),
                executorId: snapshot.executorId,
                expenseId: snapshot.expenseId,
                calculationMode: FeedStockCalculationMode(rawValue: snapshot.calculationModeRaw) ?? .manualOrPlan
            )
            foodRecord.id = snapshot.id
            context.insert(foodRecord)
            inserted = true
        }

        foodRecord.brand = snapshot.brand
        foodRecord.dailyGrams = snapshot.dailyGrams
        foodRecord.totalGrams = snapshot.totalGrams
        foodRecord.foodKindRaw = snapshot.foodKindRaw
        foodRecord.purchaseDate = snapshot.purchaseDate
        foodRecord.startDate = snapshot.startDate
        foodRecord.remainingCorrectionGrams = snapshot.remainingCorrectionGrams
        foodRecord.remainingCorrectionDate = snapshot.remainingCorrectionDate
        foodRecord.notes = snapshot.notes
        foodRecord.expenseId = snapshot.expenseId
        foodRecord.calculationModeRaw = snapshot.calculationModeRaw
        foodRecord.executorId = snapshot.executorId
        foodRecord.pet = try petReference(id: snapshot.petId, context: context)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: inserted, plan: plan)
    }

    @discardableResult
    static func insertPetWeightLogIfNeeded(
        snapshot: DomainPetWeightLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = authorize(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetWeightLog(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetWeightLog(
            date: snapshot.date,
            weight: snapshot.weight,
            weightUnit: snapshot.weightUnit,
            bcsScore: snapshot.bcsScore,
            pet: try petReference(id: snapshot.petId, context: context),
            executorId: snapshot.executorId
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertSharedCareSessionIfNeeded(
        snapshot: DomainSharedCareSessionRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainCareFactRehydrateResult {
        let plan = try authorizeSharedCareSession(snapshot: snapshot, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainCareFactRehydrateResult(inserted: false, plan: plan) }
        guard try fetchSharedCareSession(id: snapshot.id, context: context) == nil else {
            return DomainCareFactRehydrateResult(inserted: false, plan: plan)
        }
        let session = SharedCareSession(
            date: snapshot.date,
            actionKind: SharedCareActionKind(rawValue: snapshot.actionKindRaw) ?? .feeding,
            executorId: snapshot.executorId,
            executorIds: SharedCareParticipantIDs.decode(
                snapshot.executorIdsRaw,
                fallback: snapshot.executorId
            ),
            sourcePetId: snapshot.sourcePetId,
            targetPetIds: snapshot.targetPetIds,
            species: snapshot.speciesRaw,
            totalAmountGrams: snapshot.totalAmountGrams,
            totalAmountMl: snapshot.totalAmountMl,
            totalExpenseAmount: snapshot.totalExpenseAmount,
            expenseCategory: ExpenseCategory(rawValue: snapshot.expenseCategoryRaw) ?? .other,
            currencyCode: snapshot.currencyCode,
            allocationMode: SharedCareAllocationMode(rawValue: snapshot.allocationModeRaw) ?? .equal,
            foodKind: FeedFoodKind(rawValue: snapshot.foodKindRaw) ?? .dry,
            stockOwnerPetId: snapshot.stockOwnerPetId,
            primaryLegacyModelName: snapshot.primaryLegacyModelName,
            primaryLegacyModelId: snapshot.primaryLegacyModelId,
            note: snapshot.note
        )
        session.id = snapshot.id
        session.createdAt = snapshot.createdAt
        context.insert(session)
        plan.consumeAuthorization()
        return DomainCareFactRehydrateResult(inserted: true, plan: plan)
    }

    private static func authorizeSharedCareSession(
        snapshot: DomainSharedCareSessionRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> AuthorizedDomainRehydratePlan {
        let petId = try firstResolvablePetId(
            rawIds: [snapshot.sourcePetId, snapshot.stockOwnerPetId] + snapshot.targetPetIds,
            context: context
        )
        return authorize(petId: petId, source: source, context: context)
    }

    private static func firstResolvablePetId(rawIds: [String], context: ModelContext) throws -> UUID? {
        let candidateIds = rawIds.compactMap { UUID(uuidString: $0) }
        for candidateId in candidateIds where try fetchPet(id: candidateId, context: context) != nil {
            return candidateId
        }
        return candidateIds.first
    }

    private static func authorize(
        petId: UUID?,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        let request = petId.map {
            DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: $0.uuidString
            )
        } ?? DomainSubjectResolutionRequest()
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: request,
            source: source,
            context: context,
            requirement: .requiredPet
        )
    }

    private static func authorizePlant(
        plantId: UUID?,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> AuthorizedDomainRehydratePlan {
        guard let plantId else {
            return DomainRehydrateAuthorizer.rejectSubject(source: source, reason: "missingRequiredPlant")
        }
        guard try fetchPlant(id: plantId, context: context) != nil else {
            return DomainRehydrateAuthorizer.rejectSubject(source: source, reason: "unresolvedRequiredPlant")
        }
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.plant.rawValue,
                relatedEntityId: plantId.uuidString
            ),
            source: source,
            context: context,
            requirement: .household
        )
    }

    private static func petReference(id: UUID?, context: ModelContext) throws -> Pet? {
        guard let id else { return nil }
        return try fetchPet(id: id, context: context)
    }

    private static func plantReference(id: UUID?, context: ModelContext) throws -> Plant? {
        guard let id else { return nil }
        return try fetchPlant(id: id, context: context)
    }

    private static func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPlant(id: UUID, context: ModelContext) throws -> Plant? {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPlantCareLog(id: UUID, context: ModelContext) throws -> PlantCareLog? {
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { $0.id == id }
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
}
