//
//  DomainGeneralRehydrateWriteKernel.swift
//  Ohana
//
//  Central rehydrate writers for restore/cloud records that are not schedule
//  or care-fact records but still must not be constructed by restore/apply
//  entrypoints.
//

import Foundation
import SwiftData

nonisolated struct DomainPetRehydrateSnapshot: Equatable {
    let id: UUID
    let name: String
    let species: String
    let breed: String
    let birthday: Date?
    let gender: String
    let isNeutered: Bool
    let avatarEmoji: String
    let avatarImageData: Data?
    let microchipID: String
    let vetContact: String
    let vetClinicName: String
    let vetDoctorName: String
    let vetAddress: String
    let allergies: String
    let passportNumber: String
    let passportExpiryDate: Date?
    let formerName: String
    let lineageInfo: String
    let themeColorHex: String
    let homeDate: Date?
    let birthCountry: String
    let birthCity: String
    let foodBrand: String
    let restockDate: Date?
    let restockWeight: Double
    let dailyPortionGrams: Double
    let mainFoodKindRaw: String
    let foodPrice: Double
    let isShared: Bool
    let ckRecordName: String
    let createdAt: Date
    let notes: String
    let coatColor: String
    let eyeColor: String
    let currentStreak: Int
    let lastCheckInDate: Date?
    let foodTrackingModeRaw: String
    let casualOpenDate: Date?
    let casualDurationDays: Int
    let foodReminderEnabled: Bool
    let foodReminderAdvanceDays: Int
    let coconutBalance: Int
    let passedAwayDate: Date?
    let cardStyleRaw: String
    let cardPopoutImageData: Data?
    let cardPopoutSourceRaw: String?
    let weeklyWalkGoalKm: Double
    let personalityTagsRaw: String
}

nonisolated struct DomainHumanRehydrateSnapshot: Equatable {
    let id: UUID
    let name: String
    let birthday: Date?
    let bloodType: String
    let avatarEmoji: String
    let avatarImageData: Data?
    let role: String
    let genderIdentityRaw: String?
    let notes: String
    let createdAt: Date
    let nationality: String
    let city: String
    let coconutBalance: Int
    let shouldShowOnHome: Bool
    let mbti: String
    let privateFieldsRaw: String
    let themeColorHex: String
    let heightCm: Double
    let passedAwayDate: Date?
}

nonisolated struct DomainHouseholdRehydrateSnapshot: Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let totalProsperity: Int
}

nonisolated struct DomainPlantRehydrateSnapshot: Equatable {
    let id: UUID
    let name: String
    let species: String
    let avatarEmoji: String
    let avatarImageData: Data?
    let location: String
    let notes: String
    let createdAt: Date
    let lastWateredDate: Date?
    let wateringIntervalDays: Int
    let lastFertilizedDate: Date?
    let fertilizingIntervalDays: Int
    let themeColorHex: String
    let lastHealthCheckDate: Date?
    let roomNameRaw: String
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
    let lastLightMeasurementLux: Int
    let lastLightMeasurementDate: Date?
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let isNearClimateSource: Bool
    let potHasDrainage: Bool
    let acquiredDate: Date?
    let acquisitionSourceRaw: String
    let currentHeightCm: Double
    let currentSpreadCm: Double
    let isHydroponic: Bool
    let isSucculent: Bool
    let healthStatus: PlantHealthStatus
    let catalogSpeciesId: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
    let remindersEnabled: Bool
    let archivedAt: Date?
}

nonisolated struct DomainPetRelationshipRehydrateSnapshot: Equatable {
    let id: UUID
    let fromPetId: UUID
    let toPetId: UUID
    let relationshipTypeRaw: String
    let note: String
    let createdAt: Date
}

nonisolated struct DomainWaterLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let amountMl: Double
    let note: String
}

nonisolated struct DomainWishlistItemRehydrateSnapshot: Equatable {
    let id: UUID
    let title: String
    let cost: Int
    let creatorId: String
    let isRedeemed: Bool
    let createdAt: Date
}

nonisolated struct DomainCoconutAccountRehydrateSnapshot: Equatable {
    let id: UUID
    let accountKey: String
    let ownerKindRaw: String
    let ownerId: String
    let displayName: String
    let balance: Int
    let createdAt: Date
    let updatedAt: Date
    let metadataJSON: String
}

nonisolated struct DomainCoconutLedgerEntryRehydrateSnapshot: Equatable {
    let id: UUID
    let transactionKey: String
    let accountKey: String
    let ownerKindRaw: String
    let ownerId: String
    let ownerName: String
    let delta: Int
    let balanceBefore: Int
    let balanceAfter: Int
    let affectsBalance: Bool
    let entryKindRaw: String
    let sourceRaw: String
    let title: String
    let emoji: String
    let actorId: String?
    let actorName: String?
    let subjectKindRaw: String
    let subjectId: String?
    let sourceModelName: String
    let sourceModelId: String
    let careLedgerEventId: String?
    let metadataJSON: String
    let occurredAt: Date
    let createdAt: Date
}

nonisolated struct DomainEconomyBudgetUsageEventRehydrateSnapshot: Equatable {
    let id: UUID
    let dayKey: String
    let householdKey: String
    let memberKey: String
    let careObjectKey: String
    let scopeRaw: String
    let scopeKey: String
    let growthXPUsed: Int
    let coconutUsed: Int
    let luckyCoconutUsed: Int
    let actionKey: String
    let source: String
    let metadataJSON: String
    let occurredAt: Date
    let createdAt: Date
}

nonisolated struct DomainFamilyCollaborationTaskRehydrateSnapshot: Equatable {
    let id: UUID
    let title: String
    let note: String
    let kindRaw: String
    let statusRaw: String
    let relatedPetId: String?
    let relatedEventId: String?
    let relatedReminderId: String?
    let createdById: String
    let createdByName: String
    let assignedToId: String?
    let assignedToName: String?
    let claimedById: String?
    let claimedByName: String?
    let completedById: String?
    let completedByName: String?
    let rewardCoconuts: Int
    let dueAt: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let emoji: String
}

nonisolated struct DomainCoconutExchangeRequestRehydrateSnapshot: Equatable {
    let id: UUID
    let senderId: String
    let senderName: String
    let receiverId: String
    let receiverName: String
    let coconutCost: Int
    let currencyCode: String
    let localAmount: Double
    let statusRaw: String
    let createdAt: Date
    let confirmedAt: Date?
    let cancelledAt: Date?
    let updatedAt: Date
    let note: String
}

nonisolated struct DomainOasisUpgradeCoconutRehydrateSnapshot: Equatable {
    let id: UUID
    let level: Int
    let createdAt: Date
    let openedAt: Date?
    let rewardKindRaw: String
    let rewardCatalogId: String
    let guaranteedCritterId: String?
    let coconutAmount: Int
    let treeEnergyAmount: Int
    let fragmentAmount: Int
    let decorUnlockId: String?
    let storyStyleUnlockId: String?
    let temporaryEffectId: String?
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let descriptionZh: String
    let descriptionEn: String
    let descriptionDe: String
}

nonisolated struct DomainOasisElectronicPetRehydrateSnapshot: Equatable {
    let id: UUID
    let catalogId: String
    let nameZh: String
    let nameEn: String
    let nameDe: String
    let emoji: String
    let rarityRaw: String
    let nickname: String
    let level: Int
    let starLevel: Int
    let xp: Int
    let hunger: Int
    let mood: Int
    let health: Int
    let bond: Int
    let appearanceStage: Int
    let isFeaturedOnOasis: Bool
    let habitatSlot: Int
    let equippedDecorId: String
    let favoriteItemId: String
    let personalityRaw: String
    let featuredPoseRaw: String
    let sourceLevel: Int
    let obtainedAt: Date
    let lastInteractionAt: Date
    let lastStateRefreshAt: Date
    let lifeStateRaw: String
    let deathReasonRaw: String
    let riskStartedAt: Date?
    let criticalStartedAt: Date?
    let diedAt: Date?
    let lastGentlePromptAt: Date?
    let isArchived: Bool
}

nonisolated struct DomainOasisCritterFragmentRehydrateSnapshot: Equatable {
    let id: UUID
    let catalogId: String
    let amount: Int
    let updatedAt: Date
}

nonisolated struct DomainOasisUnlockRehydrateSnapshot: Equatable {
    let id: UUID
    let unlockId: String
    let unlockKindRaw: String
    let sourceLevel: Int
    let createdAt: Date
    let metadataJSON: String
}

nonisolated struct DomainOasisCritterActionLogRehydrateSnapshot: Equatable {
    let id: UUID
    let critterId: UUID?
    let critterCatalogId: String
    let actionRaw: String
    let createdAt: Date
    let coconutDelta: Int
    let fragmentDelta: Int
    let xpDelta: Int
    let sourceLevel: Int
    let noteZh: String
    let noteEn: String
    let noteDe: String
}

nonisolated struct DomainGachaOwnedItemRehydrateSnapshot: Equatable {
    let id: UUID
    let ownerHumanId: String
    let seriesId: String
    let itemId: String
    let rarityRaw: String
    let isHidden: Bool
    let ownedCount: Int
    let firstObtainedAt: Date
    let latestObtainedAt: Date
    let createdAt: Date
}

nonisolated struct DomainGachaDrawLogRehydrateSnapshot: Equatable {
    let id: UUID
    let ownerHumanId: String
    let ownerName: String
    let seriesId: String
    let itemId: String
    let rarityRaw: String
    let isHidden: Bool
    let isNew: Bool
    let outcomeKindRaw: String
    let instantResultId: String
    let instantTitleZh: String
    let instantTitleEn: String
    let instantTitleDe: String
    let instantDetailZh: String
    let instantDetailEn: String
    let instantDetailDe: String
    let instantSymbol: String
    let instantCoconutDelta: Int
    let costCoconuts: Int
    let dailySequence: Int
    let drawDate: Date
    let createdAt: Date
}

nonisolated struct DomainShopPurchaseRecordRehydrateSnapshot: Equatable {
    let id: UUID
    let transactionKey: String
    let itemId: String
    let buyerHumanId: String
    let purchasedAt: Date
    let sourceRaw: String
    let isLegacyImport: Bool
    let createdAt: Date
}

nonisolated struct DomainGeneralRehydrateResult<Model> {
    let model: Model?
    let inserted: Bool
    let plan: AuthorizedDomainRehydratePlan

    var didPersist: Bool {
        model != nil
    }
}

nonisolated enum DomainGeneralRehydrateWriter {
    @discardableResult
    static func upsertPet(
        snapshot: DomainPetRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<Pet> {
        let plan = authorizePet(snapshot.id, source: source, context: context)
        let pet: Pet
        let inserted: Bool
        if let existing = try fetchPet(id: snapshot.id, context: context) {
            pet = existing
            inserted = false
        } else {
            pet = Pet(name: snapshot.name)
            pet.id = snapshot.id
            context.insert(pet)
            inserted = true
        }
        apply(snapshot: snapshot, to: pet, plan: plan)
        return DomainGeneralRehydrateResult(model: pet, inserted: inserted, plan: plan)
    }

    @discardableResult
    static func upsertHuman(
        snapshot: DomainHumanRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<Human> {
        let plan = authorizeHuman(snapshot.id, source: source, context: context)
        let human: Human
        let inserted: Bool
        if let existing = try fetchHuman(id: snapshot.id, context: context) {
            human = existing
            inserted = false
        } else {
            human = Human(name: snapshot.name)
            human.id = snapshot.id
            context.insert(human)
            inserted = true
        }
        apply(snapshot: snapshot, to: human, plan: plan)
        return DomainGeneralRehydrateResult(model: human, inserted: inserted, plan: plan)
    }

    @discardableResult
    static func upsertHousehold(
        snapshot: DomainHouseholdRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<Household> {
        let plan = authorizeHousehold(source: source, context: context)
        let household: Household
        let inserted: Bool
        if let existing = try fetchHousehold(id: snapshot.id, context: context) {
            household = existing
            inserted = false
        } else {
            household = Household(name: snapshot.name)
            household.id = snapshot.id
            context.insert(household)
            inserted = true
        }
        plan.consumeAuthorization()
        household.name = snapshot.name
        household.createdAt = snapshot.createdAt
        household.totalProsperity = max(household.totalProsperity, snapshot.totalProsperity)
        return DomainGeneralRehydrateResult(model: household, inserted: inserted, plan: plan)
    }

    @discardableResult
    static func insertPlantIfNeeded(
        snapshot: DomainPlantRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<Plant> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchPlant(id: snapshot.id, context: context) {
            PlantUnlockPolicy.noteExistingPlantData()
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let plant = Plant(
            name: snapshot.name,
            species: snapshot.species,
            location: snapshot.location,
            avatarEmoji: snapshot.avatarEmoji,
            wateringIntervalDays: snapshot.wateringIntervalDays,
            fertilizingIntervalDays: snapshot.fertilizingIntervalDays,
            themeColorHex: snapshot.themeColorHex,
            roomNameRaw: snapshot.roomNameRaw,
            potDiameterCm: snapshot.potDiameterCm,
            potMaterialRaw: snapshot.potMaterialRaw,
            soilTypeRaw: snapshot.soilTypeRaw,
            isIndoor: snapshot.isIndoor,
            windowDirection: snapshot.windowDirection,
            lightLevel: snapshot.lightLevel,
            lastLightMeasurementLux: snapshot.lastLightMeasurementLux,
            lastLightMeasurementDate: snapshot.lastLightMeasurementDate,
            humidityPreference: snapshot.humidityPreference,
            temperaturePreference: snapshot.temperaturePreference,
            isNearClimateSource: snapshot.isNearClimateSource,
            potHasDrainage: snapshot.potHasDrainage,
            acquiredDate: snapshot.acquiredDate,
            acquisitionSourceRaw: snapshot.acquisitionSourceRaw,
            currentHeightCm: snapshot.currentHeightCm,
            currentSpreadCm: snapshot.currentSpreadCm,
            isHydroponic: snapshot.isHydroponic,
            isSucculent: snapshot.isSucculent,
            healthStatus: snapshot.healthStatus,
            catalogSpeciesId: snapshot.catalogSpeciesId,
            isToxicToCats: snapshot.isToxicToCats,
            isToxicToDogs: snapshot.isToxicToDogs,
            isToxicToChildren: snapshot.isToxicToChildren,
            isIndoorSuitable: snapshot.isIndoorSuitable,
            remindersEnabled: snapshot.remindersEnabled
        )
        plant.id = snapshot.id
        plant.notes = snapshot.notes
        plant.createdAt = snapshot.createdAt
        plant.archivedAt = snapshot.archivedAt
        plant.lastWateredDate = snapshot.lastWateredDate
        plant.lastFertilizedDate = snapshot.lastFertilizedDate
        plant.lastHealthCheckDate = snapshot.lastHealthCheckDate
        plant.updateAvatarImageData(snapshot.avatarImageData)
        plan.consumeAuthorization()
        context.insert(plant)
        PlantUnlockPolicy.noteExistingPlantData()
        return DomainGeneralRehydrateResult(model: plant, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetRelationshipIfNeeded(
        snapshot: DomainPetRelationshipRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<PetRelationship> {
        let plan = try authorizePetRelationship(snapshot: snapshot, source: source, context: context)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchPetRelationship(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let relationship = PetRelationship(
            fromPetId: snapshot.fromPetId,
            toPetId: snapshot.toPetId,
            type: PetRelationshipType(rawValue: snapshot.relationshipTypeRaw) ?? .other,
            note: snapshot.note
        )
        relationship.id = snapshot.id
        relationship.relationshipTypeRaw = snapshot.relationshipTypeRaw
        relationship.createdAt = snapshot.createdAt
        plan.consumeAuthorization()
        context.insert(relationship)
        return DomainGeneralRehydrateResult(model: relationship, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertWaterLogIfNeeded(
        snapshot: DomainWaterLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<WaterLog> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchWaterLog(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let log = WaterLog(date: snapshot.date, amountMl: snapshot.amountMl, note: snapshot.note)
        log.id = snapshot.id
        plan.consumeAuthorization()
        context.insert(log)
        return DomainGeneralRehydrateResult(model: log, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertWishlistItemIfNeeded(
        snapshot: DomainWishlistItemRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<WishlistItem> {
        let plan = authorizeHumanString(snapshot.creatorId, source: source, context: context, requirement: .requiredHuman)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchWishlistItem(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let item = WishlistItem(title: snapshot.title, cost: snapshot.cost, creatorId: snapshot.creatorId)
        item.id = snapshot.id
        item.isRedeemed = snapshot.isRedeemed
        item.createdAt = snapshot.createdAt
        plan.consumeAuthorization()
        context.insert(item)
        return DomainGeneralRehydrateResult(model: item, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertCoconutAccountIfNeeded(
        snapshot: DomainCoconutAccountRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<CoconutAccount> {
        let plan = authorizeWallet(ownerKindRaw: snapshot.ownerKindRaw, ownerId: snapshot.ownerId, source: source, context: context)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchCoconutAccount(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let account = CoconutAccount(
            id: snapshot.id,
            accountKey: snapshot.accountKey,
            ownerKind: CoconutWalletOwnerKind(rawValue: snapshot.ownerKindRaw) ?? .system,
            ownerId: snapshot.ownerId,
            displayName: snapshot.displayName,
            balance: snapshot.balance,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            metadataJSON: snapshot.metadataJSON
        )
        plan.consumeAuthorization()
        context.insert(account)
        return DomainGeneralRehydrateResult(model: account, inserted: true, plan: plan)
    }

    @discardableResult
    static func upsertCoconutLedgerEntry(
        snapshot: DomainCoconutLedgerEntryRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<CoconutLedgerEntry> {
        let plan = authorizeLedger(snapshot: snapshot, source: source, context: context)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchCoconutLedgerEntry(id: snapshot.id, context: context) {
            CoconutWalletService.reconcileFormalAccountBalancesWithLedger(context: context)
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let entry = CoconutLedgerEntry(
            id: snapshot.id,
            transactionKey: snapshot.transactionKey,
            accountKey: snapshot.accountKey,
            ownerKind: CoconutWalletOwnerKind(rawValue: snapshot.ownerKindRaw) ?? .system,
            ownerId: snapshot.ownerId,
            ownerName: snapshot.ownerName,
            delta: snapshot.delta,
            balanceBefore: snapshot.balanceBefore,
            balanceAfter: snapshot.balanceAfter,
            affectsBalance: snapshot.affectsBalance,
            entryKind: CoconutWalletEntryKind(rawValue: snapshot.entryKindRaw) ?? .adjustment,
            source: CoconutWalletSource(rawValue: snapshot.sourceRaw) ?? .importData,
            title: snapshot.title,
            emoji: snapshot.emoji,
            actorId: snapshot.actorId,
            actorName: snapshot.actorName,
            subjectKind: CareLedgerSubjectKind(rawValue: snapshot.subjectKindRaw) ?? .system,
            subjectId: snapshot.subjectId,
            sourceModelName: snapshot.sourceModelName,
            sourceModelId: snapshot.sourceModelId,
            careLedgerEventId: snapshot.careLedgerEventId,
            metadataJSON: snapshot.metadataJSON,
            occurredAt: snapshot.occurredAt,
            createdAt: snapshot.createdAt
        )
        entry.ownerKindRaw = snapshot.ownerKindRaw
        entry.entryKindRaw = snapshot.entryKindRaw
        entry.sourceRaw = snapshot.sourceRaw
        entry.subjectKindRaw = snapshot.subjectKindRaw
        plan.consumeAuthorization()
        context.insert(entry)
        CoconutWalletService.reconcileFormalAccountBalancesWithLedger(context: context)
        return DomainGeneralRehydrateResult(model: entry, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertEconomyBudgetUsageEventIfNeeded(
        snapshot: DomainEconomyBudgetUsageEventRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<EconomyBudgetUsageEvent> {
        let plan = try authorizeEconomyBudgetUsageEvent(snapshot: snapshot, source: source, context: context)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchEconomyBudgetUsageEvent(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let event = EconomyBudgetUsageEvent(
            id: snapshot.id,
            dayKey: snapshot.dayKey,
            householdKey: snapshot.householdKey,
            memberKey: snapshot.memberKey,
            careObjectKey: snapshot.careObjectKey,
            scope: EconomyBudgetUsageScope(rawValue: snapshot.scopeRaw) ?? .household,
            scopeKey: snapshot.scopeKey,
            growthXPUsed: snapshot.growthXPUsed,
            coconutUsed: snapshot.coconutUsed,
            luckyCoconutUsed: snapshot.luckyCoconutUsed,
            actionKey: snapshot.actionKey,
            source: snapshot.source,
            metadataJSON: snapshot.metadataJSON,
            occurredAt: snapshot.occurredAt,
            createdAt: snapshot.createdAt
        )
        event.scopeRaw = snapshot.scopeRaw
        plan.consumeAuthorization()
        context.insert(event)
        return DomainGeneralRehydrateResult(model: event, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertFamilyCollaborationTaskIfNeeded(
        snapshot: DomainFamilyCollaborationTaskRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<FamilyCollaborationTask> {
        let plan = authorizeFamilyTask(snapshot: snapshot, source: source, context: context)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchFamilyCollaborationTask(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let task = FamilyCollaborationTask(
            id: snapshot.id,
            title: snapshot.title,
            note: snapshot.note,
            kind: FamilyCollaborationTaskKind(rawValue: snapshot.kindRaw) ?? .householdTask,
            status: FamilyCollaborationTaskStatus(rawValue: snapshot.statusRaw) ?? .active,
            relatedPetId: snapshot.relatedPetId,
            relatedEventId: snapshot.relatedEventId,
            relatedReminderId: snapshot.relatedReminderId,
            createdById: snapshot.createdById,
            createdByName: snapshot.createdByName,
            assignedToId: snapshot.assignedToId,
            assignedToName: snapshot.assignedToName,
            rewardCoconuts: snapshot.rewardCoconuts,
            dueAt: snapshot.dueAt,
            emoji: snapshot.emoji,
            createdAt: snapshot.createdAt
        )
        task.claimedById = snapshot.claimedById
        task.claimedByName = snapshot.claimedByName
        task.completedById = snapshot.completedById
        task.completedByName = snapshot.completedByName
        task.completedAt = snapshot.completedAt
        task.updatedAt = snapshot.updatedAt
        plan.consumeAuthorization()
        context.insert(task)
        return DomainGeneralRehydrateResult(model: task, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertCoconutExchangeRequestIfNeeded(
        snapshot: DomainCoconutExchangeRequestRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<CoconutExchangeRequest> {
        let plan = authorizeHumanString(
            snapshot.senderId,
            assigneeId: snapshot.receiverId,
            source: source,
            context: context,
            requirement: .requiredHuman
        )
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        if let existing = try fetchCoconutExchangeRequest(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let request = CoconutExchangeRequest(
            id: snapshot.id,
            senderId: snapshot.senderId,
            senderName: snapshot.senderName,
            receiverId: snapshot.receiverId,
            receiverName: snapshot.receiverName,
            coconutCost: snapshot.coconutCost,
            currencyCode: snapshot.currencyCode,
            localAmount: snapshot.localAmount,
            status: CoconutExchangeRequestStatus(rawValue: snapshot.statusRaw) ?? .pending,
            createdAt: snapshot.createdAt,
            confirmedAt: snapshot.confirmedAt,
            cancelledAt: snapshot.cancelledAt,
            updatedAt: snapshot.updatedAt,
            note: snapshot.note
        )
        plan.consumeAuthorization()
        context.insert(request)
        return DomainGeneralRehydrateResult(model: request, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertOasisUpgradeCoconutIfNeeded(
        snapshot: DomainOasisUpgradeCoconutRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<OasisUpgradeCoconut> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchOasisUpgradeCoconut(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let coconut = OasisUpgradeCoconut(
            id: snapshot.id,
            level: snapshot.level,
            createdAt: snapshot.createdAt,
            openedAt: snapshot.openedAt,
            rewardKind: OasisUpgradeRewardKind(rawValue: snapshot.rewardKindRaw) ?? .coconuts,
            rewardCatalogId: snapshot.rewardCatalogId,
            guaranteedCritterId: snapshot.guaranteedCritterId,
            coconutAmount: snapshot.coconutAmount,
            treeEnergyAmount: snapshot.treeEnergyAmount,
            fragmentAmount: snapshot.fragmentAmount,
            decorUnlockId: snapshot.decorUnlockId,
            storyStyleUnlockId: snapshot.storyStyleUnlockId,
            temporaryEffectId: snapshot.temporaryEffectId,
            titleZh: snapshot.titleZh,
            titleEn: snapshot.titleEn,
            titleDe: snapshot.titleDe,
            descriptionZh: snapshot.descriptionZh,
            descriptionEn: snapshot.descriptionEn,
            descriptionDe: snapshot.descriptionDe
        )
        plan.consumeAuthorization()
        context.insert(coconut)
        return DomainGeneralRehydrateResult(model: coconut, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertOasisElectronicPetIfNeeded(
        snapshot: DomainOasisElectronicPetRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<OasisElectronicPet> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchOasisElectronicPet(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let critter = OasisElectronicPet(
            id: snapshot.id,
            catalogId: snapshot.catalogId,
            nameZh: snapshot.nameZh,
            nameEn: snapshot.nameEn,
            nameDe: snapshot.nameDe,
            emoji: snapshot.emoji,
            rarity: OasisElectronicPetRarity(rawValue: snapshot.rarityRaw) ?? .common,
            nickname: snapshot.nickname,
            level: snapshot.level,
            starLevel: snapshot.starLevel,
            xp: snapshot.xp,
            hunger: snapshot.hunger,
            mood: snapshot.mood,
            health: snapshot.health,
            bond: snapshot.bond,
            appearanceStage: snapshot.appearanceStage,
            isFeaturedOnOasis: snapshot.isFeaturedOnOasis,
            habitatSlot: snapshot.habitatSlot,
            equippedDecorId: snapshot.equippedDecorId,
            favoriteItemId: snapshot.favoriteItemId,
            personalityRaw: snapshot.personalityRaw,
            featuredPoseRaw: snapshot.featuredPoseRaw,
            sourceLevel: snapshot.sourceLevel,
            obtainedAt: snapshot.obtainedAt,
            lastInteractionAt: snapshot.lastInteractionAt,
            lastStateRefreshAt: snapshot.lastStateRefreshAt,
            lifeStateRaw: snapshot.lifeStateRaw,
            deathReasonRaw: snapshot.deathReasonRaw,
            riskStartedAt: snapshot.riskStartedAt,
            criticalStartedAt: snapshot.criticalStartedAt,
            diedAt: snapshot.diedAt,
            lastGentlePromptAt: snapshot.lastGentlePromptAt,
            isArchived: snapshot.isArchived
        )
        plan.consumeAuthorization()
        context.insert(critter)
        return DomainGeneralRehydrateResult(model: critter, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertOasisCritterFragmentIfNeeded(
        snapshot: DomainOasisCritterFragmentRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<OasisCritterFragmentBalance> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchOasisCritterFragment(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let fragment = OasisCritterFragmentBalance(
            id: snapshot.id,
            catalogId: snapshot.catalogId,
            amount: snapshot.amount,
            updatedAt: snapshot.updatedAt
        )
        plan.consumeAuthorization()
        context.insert(fragment)
        return DomainGeneralRehydrateResult(model: fragment, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertOasisUnlockIfNeeded(
        snapshot: DomainOasisUnlockRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<OasisUnlock> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchOasisUnlock(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let unlock = OasisUnlock(
            id: snapshot.id,
            unlockId: snapshot.unlockId,
            unlockKind: OasisUpgradeRewardKind(rawValue: snapshot.unlockKindRaw) ?? .decoration,
            sourceLevel: snapshot.sourceLevel,
            createdAt: snapshot.createdAt,
            metadataJSON: snapshot.metadataJSON
        )
        plan.consumeAuthorization()
        context.insert(unlock)
        return DomainGeneralRehydrateResult(model: unlock, inserted: true, plan: plan)
    }

    @discardableResult
    static func insertOasisCritterActionLogIfNeeded(
        snapshot: DomainOasisCritterActionLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<OasisCritterActionLog> {
        let plan = authorizeHousehold(source: source, context: context)
        if let existing = try fetchOasisCritterActionLog(id: snapshot.id, context: context) {
            return DomainGeneralRehydrateResult(model: existing, inserted: false, plan: plan)
        }
        let log = OasisCritterActionLog(
            id: snapshot.id,
            critterId: snapshot.critterId,
            critterCatalogId: snapshot.critterCatalogId,
            action: OasisCritterAction(rawValue: snapshot.actionRaw) ?? .rest,
            createdAt: snapshot.createdAt,
            coconutDelta: snapshot.coconutDelta,
            fragmentDelta: snapshot.fragmentDelta,
            xpDelta: snapshot.xpDelta,
            sourceLevel: snapshot.sourceLevel,
            noteZh: snapshot.noteZh,
            noteEn: snapshot.noteEn,
            noteDe: snapshot.noteDe
        )
        plan.consumeAuthorization()
        context.insert(log)
        return DomainGeneralRehydrateResult(model: log, inserted: true, plan: plan)
    }

    @discardableResult
    static func upsertGachaOwnedItem(
        snapshot: DomainGachaOwnedItemRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<GachaOwnedItem> {
        let plan = authorizeHumanString(snapshot.ownerHumanId, source: source, context: context, requirement: .requiredHuman)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        let item: GachaOwnedItem
        let inserted: Bool
        if let existing = try fetchGachaOwnedItem(id: snapshot.id, context: context) {
            item = existing
            inserted = false
        } else {
            item = GachaOwnedItem()
            item.id = snapshot.id
            context.insert(item)
            inserted = true
        }
        plan.consumeAuthorization()
        item.ownerHumanId = snapshot.ownerHumanId
        item.seriesId = snapshot.seriesId
        item.itemId = snapshot.itemId
        item.rarityRaw = snapshot.rarityRaw
        item.isHidden = snapshot.isHidden
        item.ownedCount = inserted ? snapshot.ownedCount : max(item.ownedCount, snapshot.ownedCount)
        item.firstObtainedAt = snapshot.firstObtainedAt
        item.latestObtainedAt = snapshot.latestObtainedAt
        item.createdAt = snapshot.createdAt
        return DomainGeneralRehydrateResult(model: item, inserted: inserted, plan: plan)
    }

    @discardableResult
    static func upsertGachaDrawLog(
        snapshot: DomainGachaDrawLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<GachaDrawLog> {
        let plan = authorizeHumanString(snapshot.ownerHumanId, source: source, context: context, requirement: .requiredHuman)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        let log: GachaDrawLog
        let inserted: Bool
        if let existing = try fetchGachaDrawLog(id: snapshot.id, context: context) {
            log = existing
            inserted = false
        } else {
            log = GachaDrawLog()
            log.id = snapshot.id
            context.insert(log)
            inserted = true
        }
        plan.consumeAuthorization()
        apply(snapshot: snapshot, to: log)
        return DomainGeneralRehydrateResult(model: log, inserted: inserted, plan: plan)
    }

    @discardableResult
    static func upsertShopPurchaseRecord(
        snapshot: DomainShopPurchaseRecordRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainGeneralRehydrateResult<ShopPurchaseRecord> {
        let plan = authorizeHumanString(snapshot.buyerHumanId, source: source, context: context, requirement: .requiredHuman)
        guard plan.disposition.allowsPersistence else {
            return DomainGeneralRehydrateResult(model: nil, inserted: false, plan: plan)
        }
        let purchase: ShopPurchaseRecord
        let inserted: Bool
        if let existing = try fetchShopPurchaseRecord(id: snapshot.id, context: context)
            ?? fetchShopPurchaseRecord(transactionKey: snapshot.transactionKey, context: context) {
            purchase = existing
            purchase.id = snapshot.id
            inserted = false
        } else {
            purchase = ShopPurchaseRecord(
                id: snapshot.id,
                transactionKey: snapshot.transactionKey,
                itemId: snapshot.itemId,
                buyerHumanId: snapshot.buyerHumanId,
                purchasedAt: snapshot.purchasedAt,
                sourceRaw: snapshot.sourceRaw,
                isLegacyImport: snapshot.isLegacyImport,
                createdAt: snapshot.createdAt
            )
            context.insert(purchase)
            inserted = true
        }
        plan.consumeAuthorization()
        purchase.transactionKey = snapshot.transactionKey
        purchase.itemId = snapshot.itemId
        purchase.buyerHumanId = snapshot.buyerHumanId
        purchase.purchasedAt = snapshot.purchasedAt
        purchase.sourceRaw = snapshot.sourceRaw
        purchase.isLegacyImport = snapshot.isLegacyImport
        purchase.createdAt = snapshot.createdAt
        return DomainGeneralRehydrateResult(model: purchase, inserted: inserted, plan: plan)
    }

    private static func apply(snapshot: DomainPetRehydrateSnapshot, to pet: Pet, plan: AuthorizedDomainRehydratePlan) {
        plan.consumeAuthorization()
        pet.name = snapshot.name
        pet.species = snapshot.species
        pet.breed = snapshot.breed
        pet.birthday = snapshot.birthday
        pet.gender = snapshot.gender
        pet.isNeutered = snapshot.isNeutered
        pet.avatarEmoji = snapshot.avatarEmoji
        pet.updateAvatarImageData(snapshot.avatarImageData)
        pet.microchipID = snapshot.microchipID
        pet.vetContact = snapshot.vetContact
        pet.vetClinicName = snapshot.vetClinicName
        pet.vetDoctorName = snapshot.vetDoctorName
        pet.vetAddress = snapshot.vetAddress
        pet.allergies = snapshot.allergies
        pet.passportNumber = snapshot.passportNumber
        pet.passportExpiryDate = snapshot.passportExpiryDate
        pet.formerName = snapshot.formerName
        pet.lineageInfo = snapshot.lineageInfo
        pet.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            snapshot.themeColorHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        pet.homeDate = snapshot.homeDate
        pet.birthCountry = snapshot.birthCountry
        pet.birthCity = snapshot.birthCity
        pet.foodBrand = snapshot.foodBrand
        pet.restockDate = snapshot.restockDate
        pet.restockWeight = snapshot.restockWeight
        pet.dailyPortionGrams = snapshot.dailyPortionGrams
        pet.mainFoodKindRaw = snapshot.mainFoodKindRaw
        pet.foodPrice = snapshot.foodPrice
        pet.isShared = snapshot.isShared
        pet.ckRecordName = snapshot.ckRecordName
        pet.createdAt = snapshot.createdAt
        pet.notes = snapshot.notes
        pet.coatColor = snapshot.coatColor
        pet.eyeColor = snapshot.eyeColor
        pet.currentStreak = snapshot.currentStreak
        pet.lastCheckInDate = snapshot.lastCheckInDate
        pet.foodTrackingModeRaw = snapshot.foodTrackingModeRaw
        pet.casualOpenDate = snapshot.casualOpenDate
        pet.casualDurationDays = snapshot.casualDurationDays
        pet.foodReminderEnabled = snapshot.foodReminderEnabled
        pet.foodReminderAdvanceDays = snapshot.foodReminderAdvanceDays
        pet.passedAwayDate = snapshot.passedAwayDate
        pet.cardStyleRaw = snapshot.cardStyleRaw
        pet.cardPopoutImageData = snapshot.cardPopoutImageData
        pet.cardPopoutSourceRaw = snapshot.cardPopoutSourceRaw
        pet.weeklyWalkGoalKm = snapshot.weeklyWalkGoalKm
        pet.personalityTagsRaw = snapshot.personalityTagsRaw
    }

    private static func apply(snapshot: DomainHumanRehydrateSnapshot, to human: Human, plan: AuthorizedDomainRehydratePlan) {
        plan.consumeAuthorization()
        human.name = snapshot.name
        human.birthday = snapshot.birthday
        human.bloodType = snapshot.bloodType
        human.avatarEmoji = snapshot.avatarEmoji
        human.updateAvatarImageData(snapshot.avatarImageData)
        human.role = HumanProfileOptions.normalizedRole(snapshot.role)
        human.appleUserIdentifier = ""
        human.genderIdentityRaw = HumanProfileOptions.storedGenderIdentity(snapshot.genderIdentityRaw ?? "")
        human.notes = snapshot.notes
        human.createdAt = snapshot.createdAt
        human.nationality = snapshot.nationality
        human.city = snapshot.city
        human.shouldShowOnHome = snapshot.shouldShowOnHome
        human.mbti = snapshot.mbti
        human.privateFieldsRaw = snapshot.privateFieldsRaw
        human.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            snapshot.themeColorHex,
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )
        human.heightCm = snapshot.heightCm
        human.passedAwayDate = snapshot.passedAwayDate
    }

    private static func apply(snapshot: DomainGachaDrawLogRehydrateSnapshot, to log: GachaDrawLog) {
        log.ownerHumanId = snapshot.ownerHumanId
        log.ownerName = snapshot.ownerName
        log.seriesId = snapshot.seriesId
        log.itemId = snapshot.itemId
        log.rarityRaw = snapshot.rarityRaw
        log.isHidden = snapshot.isHidden
        log.isNew = snapshot.isNew
        log.outcomeKindRaw = snapshot.outcomeKindRaw
        log.instantResultId = snapshot.instantResultId
        log.instantTitleZh = snapshot.instantTitleZh
        log.instantTitleEn = snapshot.instantTitleEn
        log.instantTitleDe = snapshot.instantTitleDe
        log.instantDetailZh = snapshot.instantDetailZh
        log.instantDetailEn = snapshot.instantDetailEn
        log.instantDetailDe = snapshot.instantDetailDe
        log.instantSymbol = snapshot.instantSymbol
        log.instantCoconutDelta = snapshot.instantCoconutDelta
        log.costCoconuts = snapshot.costCoconuts
        log.dailySequence = snapshot.dailySequence
        log.drawDate = snapshot.drawDate
        log.createdAt = snapshot.createdAt
    }

    private static func authorizePet(_ id: UUID, source: DomainRehydrateSourceKind, context: ModelContext) -> AuthorizedDomainRehydratePlan {
        DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: id.uuidString
            ),
            source: source,
            context: context
        )
    }

    private static func authorizeHuman(_ id: UUID, source: DomainRehydrateSourceKind, context: ModelContext) -> AuthorizedDomainRehydratePlan {
        authorizeHumanString(id.uuidString, source: source, context: context)
    }

    private static func authorizeHumanString(
        _ id: String,
        assigneeId: String? = nil,
        source: DomainRehydrateSourceKind,
        context: ModelContext,
        requirement: DomainRehydrateSubjectRequirement = .historyCompatible
    ) -> AuthorizedDomainRehydratePlan {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = trimmed.isEmpty
            ? DomainSubjectResolutionRequest(assigneeId: assigneeId)
            : DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: trimmed,
                assigneeId: assigneeId
            )
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: request,
            source: source,
            context: context,
            requirement: requirement
        )
    }

    private static func authorizePetRelationship(
        snapshot: DomainPetRelationshipRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> AuthorizedDomainRehydratePlan {
        guard try fetchPet(id: snapshot.toPetId, context: context) != nil else {
            return DomainRehydrateAuthorizer.rejectSubject(source: source, reason: "unresolvedRelationshipTargetPet")
        }
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: snapshot.fromPetId.uuidString
            ),
            source: source,
            context: context,
            requirement: .requiredPet
        )
    }

    private static func authorizeEconomyBudgetUsageEvent(
        snapshot: DomainEconomyBudgetUsageEventRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> AuthorizedDomainRehydratePlan {
        if let petId = try firstResolvablePetId(
            rawIds: [snapshot.careObjectKey, snapshot.scopeKey],
            context: context
        ) {
            return DomainRehydrateAuthorizer.authorizeSubject(
                request: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: petId.uuidString
                ),
                source: source,
                context: context,
                requirement: .requiredPet
            )
        }
        if let humanId = try firstResolvableHumanId(
            rawIds: [snapshot.memberKey, snapshot.scopeKey],
            context: context
        ) {
            return authorizeHumanString(
                humanId.uuidString,
                source: source,
                context: context,
                requirement: .requiredHuman
            )
        }
        return authorizeHousehold(source: source, context: context)
    }

    private static func authorizeWallet(
        ownerKindRaw: String,
        ownerId: String,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        guard let ownerKind = CoconutWalletOwnerKind(rawValue: ownerKindRaw) else {
            return DomainRehydrateAuthorizer.rejectSubject(source: source, reason: "invalidWalletOwnerKind")
        }
        switch ownerKind {
        case .pet:
            return DomainRehydrateAuthorizer.authorizeSubject(
                request: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: ownerId
                ),
                source: source,
                context: context,
                requirement: .requiredPet
            )
        case .human:
            return authorizeHumanString(ownerId, source: source, context: context, requirement: .requiredHuman)
        case .system:
            return authorizeHousehold(source: source, context: context)
        }
    }

    private static func authorizeLedger(
        snapshot: DomainCoconutLedgerEntryRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        authorizeWallet(ownerKindRaw: snapshot.ownerKindRaw, ownerId: snapshot.ownerId, source: source, context: context)
    }

    private static func authorizeFamilyTask(
        snapshot: DomainFamilyCollaborationTaskRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        if let relatedPetId = snapshot.relatedPetId, !relatedPetId.isEmpty {
            return DomainRehydrateAuthorizer.authorizeSubject(
                request: DomainSubjectResolutionRequest(
                    relatedEntityType: EntityKind.pet.rawValue,
                    relatedEntityId: relatedPetId,
                    assigneeId: snapshot.assignedToId
                ),
                source: source,
                context: context,
                requirement: .requiredPet
            )
        }
        return authorizeHumanString(
            snapshot.createdById,
            assigneeId: snapshot.assignedToId,
            source: source,
            context: context,
            requirement: .requiredHuman
        )
    }

    private static func authorizeHousehold(
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        DomainRehydrateAuthorizer.authorizeSubject(
            request: DomainSubjectResolutionRequest(),
            source: source,
            context: context,
            requirement: .household
        )
    }

    private static func firstResolvablePetId(rawIds: [String], context: ModelContext) throws -> UUID? {
        let candidateIds = rawIds.compactMap { UUID(uuidString: $0) }
        for candidateId in candidateIds where try fetchPet(id: candidateId, context: context) != nil {
            return candidateId
        }
        return nil
    }

    private static func firstResolvableHumanId(rawIds: [String], context: ModelContext) throws -> UUID? {
        let candidateIds = rawIds.compactMap { UUID(uuidString: $0) }
        for candidateId in candidateIds where try fetchHuman(id: candidateId, context: context) != nil {
            return candidateId
        }
        return nil
    }
}
