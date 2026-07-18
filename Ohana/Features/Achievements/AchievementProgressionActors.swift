//
//  AchievementProgressionActors.swift
//  Ohana
//
//  Bounded background reconciliation and immutable wall snapshots.
//

import Foundation
import SwiftData

nonisolated enum AchievementReconcileReason: String, Codable, Sendable {
    case domainRevision
    case launch
    case foreground
    case wallOpened
    case legacyMigration
    case explicit
}

nonisolated struct AchievementProgressionRequest: Equatable, Sendable {
    let affectedScopes: [AchievementScopeReference]
    let reason: AchievementReconcileReason
    let now: Date

    init(
        affectedScopes: [AchievementScopeReference] = [],
        reason: AchievementReconcileReason,
        now: Date = Date()
    ) {
        self.affectedScopes = affectedScopes
        self.reason = reason
        self.now = now
    }
}

nonisolated struct AchievementProgressionSummary: Equatable, Sendable {
    let evaluatedScopeCount: Int
    let insertedUnlockKeys: [String]
    let retainedUnlockCount: Int
}

nonisolated struct AchievementWallItemSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let achievementKey: String
    let definitionID: String
    let scope: AchievementScopeReference
    let category: AchievementCategory
    let emoji: String
    let artworkName: String
    let title: AchievementLocalizedCopy
    let condition: AchievementLocalizedCopy
    let reward: AchievementReward
    let unlockedAt: Date?
    let claimedAt: Date?

    var isUnlocked: Bool { unlockedAt != nil }
    var isClaimed: Bool { claimedAt != nil }
    var isClaimable: Bool { isUnlocked && !isClaimed }
}

nonisolated struct AchievementWallSnapshot: Equatable, Sendable {
    let generatedAt: Date
    let scopes: [AchievementScopeReference]
    let items: [AchievementWallItemSnapshot]

    var totalCount: Int { items.count }
    var unlockedCount: Int { items.count(where: \.isUnlocked) }
    var claimableCount: Int { items.count(where: \.isClaimable) }
    var nextTarget: AchievementWallItemSnapshot? { items.first(where: { !$0.isUnlocked }) }

    static let empty = AchievementWallSnapshot(generatedAt: .distantPast, scopes: [], items: [])
}

@ModelActor
actor AchievementProgressionActor {
    func reconcile(_ request: AchievementProgressionRequest) throws -> AchievementProgressionSummary {
        try AchievementProgressionEngine.reconcile(request, context: modelContext)
    }
}

@ModelActor
actor AchievementWallReadActor {
    private static let factFetchLimit = 20000

    func load(scopes: [AchievementScopeReference], now: Date = Date()) throws -> AchievementWallSnapshot {
        var unlockDescriptor = FetchDescriptor<AchievementUnlock>(
            sortBy: [SortDescriptor(\.unlockedAt)]
        )
        unlockDescriptor.fetchLimit = Self.factFetchLimit
        var receiptDescriptor = FetchDescriptor<AchievementRewardReceipt>(
            sortBy: [SortDescriptor(\.claimedAt)]
        )
        receiptDescriptor.fetchLimit = Self.factFetchLimit

        let unlocks = try modelContext.fetch(unlockDescriptor)
        let receipts = try modelContext.fetch(receiptDescriptor)
        let unlockByKey = Dictionary(uniqueKeysWithValues: unlocks.map { ($0.achievementKey, $0.unlockedAt) })
        let receiptByKey = Dictionary(uniqueKeysWithValues: receipts.map { ($0.achievementKey, $0.claimedAt) })
        var unlockByScopeAndDefinition: [String: Date] = [:]
        var receiptByScopeAndDefinition: [String: Date] = [:]
        var legacyGlobalUnlockByDefinition: [String: Date] = [:]
        var legacyGlobalReceiptByDefinition: [String: Date] = [:]

        for unlock in unlocks {
            let scopedKey = factLookupKey(
                scopeKindRaw: unlock.scopeKindRaw,
                scopeIDRaw: unlock.scopeIDRaw,
                achievementID: unlock.achievementID
            )
            unlockByScopeAndDefinition[scopedKey] = min(
                unlockByScopeAndDefinition[scopedKey] ?? unlock.unlockedAt,
                unlock.unlockedAt
            )
            if unlock.achievementID.hasPrefix("global_") {
                legacyGlobalUnlockByDefinition[unlock.achievementID] = min(
                    legacyGlobalUnlockByDefinition[unlock.achievementID] ?? unlock.unlockedAt,
                    unlock.unlockedAt
                )
            }
        }
        for receipt in receipts {
            let scopedKey = factLookupKey(
                scopeKindRaw: receipt.scopeKindRaw,
                scopeIDRaw: receipt.scopeIDRaw,
                achievementID: receipt.achievementID
            )
            receiptByScopeAndDefinition[scopedKey] = min(
                receiptByScopeAndDefinition[scopedKey] ?? receipt.claimedAt,
                receipt.claimedAt
            )
            if receipt.achievementID.hasPrefix("global_") {
                legacyGlobalReceiptByDefinition[receipt.achievementID] = min(
                    legacyGlobalReceiptByDefinition[receipt.achievementID] ?? receipt.claimedAt,
                    receipt.claimedAt
                )
            }
        }

        let items = scopes.flatMap { scope in
            AchievementDefinitionCatalog.definitions(scope: scope.kind).map { definition in
                let key = scope.achievementKey(for: definition.id)
                let scopedKey = factLookupKey(
                    scopeKindRaw: scope.kind.rawValue,
                    scopeIDRaw: scope.id,
                    achievementID: definition.id
                )
                let unlockedAt = unlockByKey[key]
                    ?? unlockByScopeAndDefinition[scopedKey]
                    ?? (scope.kind == .island ? legacyGlobalUnlockByDefinition[definition.id] : nil)
                let claimedAt = receiptByKey[key]
                    ?? receiptByScopeAndDefinition[scopedKey]
                    ?? (scope.kind == .island ? legacyGlobalReceiptByDefinition[definition.id] : nil)
                return AchievementWallItemSnapshot(
                    id: key,
                    achievementKey: key,
                    definitionID: definition.id,
                    scope: scope,
                    category: definition.category,
                    emoji: definition.emoji,
                    artworkName: definition.artworkName,
                    title: definition.title,
                    condition: definition.condition,
                    reward: definition.reward,
                    unlockedAt: unlockedAt,
                    claimedAt: claimedAt
                )
            }
        }
        return AchievementWallSnapshot(
            generatedAt: now,
            scopes: scopes,
            items: items
        )
    }

    private func factLookupKey(
        scopeKindRaw: String,
        scopeIDRaw: String,
        achievementID: String
    ) -> String {
        "\(scopeKindRaw)|\(scopeIDRaw.lowercased())|\(achievementID)"
    }
}

nonisolated enum AchievementProgressionEngine {
    private static let memberFetchLimit = 128
    private static let activityFetchLimit = 10000

    static func reconcile(
        _ request: AchievementProgressionRequest,
        context: ModelContext
    ) throws -> AchievementProgressionSummary {
        let scopes = try request.affectedScopes.isEmpty
            ? allActiveScopes(context: context)
            : request.affectedScopes
        let existingKeys = try fetchExistingKeys(scopes: scopes, context: context)
        var candidates: [(definitionID: String, scope: AchievementScopeReference)] = []

        for scope in scopes {
            let unlockedIDs: [String] = switch scope.kind {
            case .pet:
                try evaluatePet(scope: scope, context: context)
            case .human:
                try evaluateHuman(scope: scope, now: request.now, context: context)
            case .island:
                try evaluateIsland(context: context)
            case .legacyUnknown:
                []
            }
            candidates += unlockedIDs.map { ($0, scope) }
        }

        var insertedKeys: [String] = []
        for candidate in candidates {
            guard let definition = AchievementDefinitionCatalog.definition(id: candidate.definitionID),
                  definition.scope == candidate.scope.kind else { continue }
            let key = candidate.scope.achievementKey(for: definition.id)
            guard !existingKeys.contains(key), !insertedKeys.contains(key) else { continue }
            context.insert(
                AchievementUnlock(
                    achievementKey: key,
                    achievementID: definition.id,
                    scopeKindRaw: candidate.scope.kind.rawValue,
                    scopeIDRaw: candidate.scope.id,
                    unlockedAt: request.now,
                    createdAt: request.now
                )
            )
            insertedKeys.append(key)
        }

        if !insertedKeys.isEmpty {
            let save = context.safeSaveResult(publishFailureEvent: true)
            guard save.didSave else {
                context.rollback()
                throw AchievementProgressionError.persistenceFailed(
                    save.errorDescription ?? "Unable to save achievement unlocks."
                )
            }
        }
        return AchievementProgressionSummary(
            evaluatedScopeCount: scopes.count,
            insertedUnlockKeys: insertedKeys.sorted(),
            retainedUnlockCount: existingKeys.count
        )
    }

    private static func allActiveScopes(context: ModelContext) throws -> [AchievementScopeReference] {
        var petDescriptor = FetchDescriptor<Pet>(predicate: #Predicate { $0.passedAwayDate == nil })
        petDescriptor.fetchLimit = memberFetchLimit
        var humanDescriptor = FetchDescriptor<Human>(predicate: #Predicate { $0.passedAwayDate == nil })
        humanDescriptor.fetchLimit = memberFetchLimit
        let pets = try context.fetch(petDescriptor)
        let humans = try context.fetch(humanDescriptor)
        return pets.map { .pet($0.id) } + humans.map { .human($0.id) } + [.island]
    }

    private static func fetchExistingKeys(
        scopes: [AchievementScopeReference],
        context: ModelContext
    ) throws -> Set<String> {
        let allowed = Set(scopes.map { "\($0.kind.rawValue)|\($0.id)" })
        var descriptor = FetchDescriptor<AchievementUnlock>()
        descriptor.fetchLimit = activityFetchLimit
        return Set(try context.fetch(descriptor).compactMap { unlock in
            allowed.contains("\(unlock.scopeKindRaw)|\(unlock.scopeIDRaw)") ? unlock.achievementKey : nil
        })
    }

    private static func evaluatePet(
        scope: AchievementScopeReference,
        context: ModelContext
    ) throws -> [String] {
        guard let id = UUID(uuidString: scope.id) else { return [] }
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate { $0.id == id && $0.passedAwayDate == nil }
        )
        descriptor.fetchLimit = 1
        guard let pet = try context.fetch(descriptor).first else { return [] }
        let subjectKind = CareLedgerSubjectKind.pet.rawValue
        let subjectID = id.uuidString
        var ledgerDescriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate { event in
                event.subjectKind == subjectKind && event.subjectId == subjectID
            }
        )
        ledgerDescriptor.fetchLimit = activityFetchLimit
        let activity = AchievementPetActivitySummary(
            foodRecordDates: pet.foodRecords.map(\.startDate),
            photoDates: pet.photoLogs.map(\.date),
            milestoneDates: pet.milestones.map(\.date),
            documentIssueDates: pet.documents.compactMap(\.issueDate),
            insuranceCreatedDates: pet.insurances.map(\.createdAt),
            activeMedicationEndDates: pet.medications.compactMap(\.endDate),
            symptomDates: pet.symptomLogs.map(\.date),
            documentCount: pet.documents.count,
            insuranceCount: pet.insurances.count
        )
        let computation = AchievementComputationContext(
            allPets: [pet],
            careLedgerEvents: try context.fetch(ledgerDescriptor),
            petActivitySummaries: [pet.id: activity]
        )
        return AchievementManager.compute(for: pet, context: computation)
            .filter { AchievementDefinitionCatalog.definition(id: $0.id)?.scope == .pet && $0.isUnlocked }
            .map(\.id)
    }

    private static func evaluateHuman(
        scope: AchievementScopeReference,
        now: Date,
        context: ModelContext
    ) throws -> [String] {
        guard let id = UUID(uuidString: scope.id) else { return [] }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate { $0.id == id && $0.passedAwayDate == nil }
        )
        descriptor.fetchLimit = 1
        guard let human = try context.fetch(descriptor).first else { return [] }
        let humanID = id.uuidString
        var medicationDescriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate { $0.humanId == humanID }
        )
        medicationDescriptor.fetchLimit = activityFetchLimit
        var medicationLogDescriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate { $0.humanId == humanID }
        )
        medicationLogDescriptor.fetchLimit = activityFetchLimit
        var expenseDescriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate { $0.executorId == humanID }
        )
        expenseDescriptor.fetchLimit = activityFetchLimit
        let medications = try context.fetch(medicationDescriptor)
        let medicationLogs = try context.fetch(medicationLogDescriptor)
        let expenses = try context.fetch(expenseDescriptor)
        let taken = medicationLogs.count(where: { $0.status == .taken })
        let days = Calendar.current.dateComponents([.day], from: human.createdAt, to: now).day ?? 0
        let hasAnyRecord = !human.weightLogs.isEmpty
            || !human.workoutLogs.isEmpty
            || !medications.isEmpty
            || !medicationLogs.isEmpty
            || !expenses.isEmpty

        let conditions: [String: Bool] = [
            "human_profile_ready": HumanBasicProfileAchievementPolicy.isReady(human),
            "human_first_record": hasAnyRecord,
            "human_weight_starter": !human.weightLogs.isEmpty,
            "human_weight_keeper": human.weightLogs.count >= 7,
            "human_expense_tracker": expenses.count >= 5,
            "human_medication_setup": !medications.isEmpty,
            "human_medication_keeper": taken >= 7,
            "human_workout_starter": !human.workoutLogs.isEmpty,
            "human_workout_rhythm": human.workoutLogs.count >= 10,
            "human_workout_hero": human.workoutLogs.count >= 30,
            "human_coconut_saver": human.coconutBalance >= 500,
            "human_coconut_elite": human.coconutBalance >= 2000,
            "human_old_friend": days >= 7,
            "human_year_friend": days >= 365
        ]
        return conditions.compactMap { $0.value ? $0.key : nil }
    }

    private static func evaluateIsland(context: ModelContext) throws -> [String] {
        var humanDescriptor = FetchDescriptor<Human>(predicate: #Predicate { $0.passedAwayDate == nil })
        humanDescriptor.fetchLimit = memberFetchLimit
        var petDescriptor = FetchDescriptor<Pet>(predicate: #Predicate { $0.passedAwayDate == nil })
        petDescriptor.fetchLimit = memberFetchLimit
        var critterDescriptor = FetchDescriptor<OasisElectronicPet>()
        critterDescriptor.fetchLimit = 256
        var actionDescriptor = FetchDescriptor<OasisCritterActionLog>()
        actionDescriptor.fetchLimit = activityFetchLimit
        var ownedDescriptor = FetchDescriptor<GachaOwnedItem>()
        ownedDescriptor.fetchLimit = activityFetchLimit
        var drawDescriptor = FetchDescriptor<GachaDrawLog>()
        drawDescriptor.fetchLimit = activityFetchLimit
        let humans = try context.fetch(humanDescriptor)
        let pets = try context.fetch(petDescriptor)
        let critters = try context.fetch(critterDescriptor)
        let actions = try context.fetch(actionDescriptor)
        let owned = try context.fetch(ownedDescriptor)
        let draws = try context.fetch(drawDescriptor)
        let conditions: [String: Bool] = [
            "global_island_crew": humans.count + pets.count >= 2,
            "global_first_critter": !critters.isEmpty,
            "global_legendary_critter": critters.contains { $0.rarity == .legendary },
            "global_critter_collector": Set(critters.map(\.catalogId)).count >= 3,
            "global_critter_star": critters.contains { $0.starLevel >= 2 },
            "global_critter_caretaker": actions.count(where: {
                switch $0.action {
                case .feed, .play, .rest, .rescue:
                    true
                case .levelUpgrade, .starUpgrade, .unlock, .fragmentAwaken, .feature, .careEcho, .death:
                    false
                }
            }) >= 10,
            "global_first_blind_box": !draws.isEmpty,
            "global_blind_box_collector": Set(owned.map { "\($0.seriesId)#\($0.itemId)" }).count >= 8,
            "global_secret_blind_box": owned.contains(where: \.isHidden),
            "global_gacha_series_complete": AchievementManager.completedGachaSeriesCount(owned) >= 1,
            "global_gacha_jackpot": draws.contains { $0.instantCoconutDelta >= 500 }
        ]
        return conditions.compactMap { $0.value ? $0.key : nil }
    }
}

nonisolated enum AchievementProgressionError: LocalizedError, Equatable, Sendable {
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message): message
        }
    }
}
