//
//  SharedCareSession.swift
//  Ohana
//
//  One real-world care action that applies to multiple same-species pets.
//

import Foundation
import SwiftData

enum SharedCareActionKind: String, Codable, CaseIterable {
    case feeding
    case watering
    case pottyUnknown
    case litterScoop
    case litterChange
    case waterChange
    case filterClean
    case cageCleaning
    case freeFlight
    case misting
    case substrateChange
    case play
    case walk
    case expense
}

enum SharedCareAllocationMode: String, Codable, CaseIterable {
    case equal
    case unknown
}

enum SharedCareMetadata {
    static let sharedFeedNotePrefix = "ohana_shared_feed:"
    static let sharedWaterNotePrefix = "ohana_shared_water:"
    static let sharedLitterNotePrefix = "ohana_shared_litter:"
    static let unknownPottyNotePrefix = "ohana_shared_unknown_potty:"
    static let sharedCareNotePrefix = "ohana_shared_care:"
    static let sharedWalkNotePrefix = "ohana_shared_walk:"
    static let sharedExpenseNotePrefix = "ohana_shared_expense:"
    static let stockTotalKey = "stockTotal="
    static let stockOwnerKey = "stockOwner=1"

    static func note(prefix: String, sessionId: UUID, stockTotalGrams: Double? = nil, isStockOwner: Bool = false) -> String {
        var parts = ["\(prefix)\(sessionId.uuidString)"]
        if let stockTotalGrams {
            parts.append("\(stockTotalKey)\(Int(stockTotalGrams.rounded()))")
        }
        if isStockOwner {
            parts.append(stockOwnerKey)
        }
        return parts.joined(separator: " ")
    }

    static func stockDeductionGrams(from note: String) -> Double? {
        guard note.contains(stockOwnerKey),
              let token = note.split(separator: " ").first(where: { $0.hasPrefix(stockTotalKey) }) else {
            return nil
        }
        return Double(token.dropFirst(stockTotalKey.count))
    }

    static func prefix(for actionKind: SharedCareActionKind) -> String {
        switch actionKind {
        case .feeding:
            return sharedFeedNotePrefix
        case .watering:
            return sharedWaterNotePrefix
        case .litterScoop, .litterChange:
            return sharedLitterNotePrefix
        case .pottyUnknown:
            return unknownPottyNotePrefix
        case .walk:
            return sharedWalkNotePrefix
        case .expense:
            return sharedExpenseNotePrefix
        case .waterChange, .filterClean, .cageCleaning, .freeFlight, .misting, .substrateChange, .play:
            return "\(sharedCareNotePrefix)\(actionKind.rawValue):"
        }
    }
}

@Model
final class SharedCareSession {
    #Index<SharedCareSession>([\.date])
    var id: UUID = UUID()
    var date: Date = Date()
    var actionKindRaw: String = SharedCareActionKind.feeding.rawValue
    var executorId: String?
    var sourcePetId: String = ""
    var targetPetIdsRaw: String = ""
    var speciesRaw: String = ""
    var totalAmountGrams: Double = 0
    var totalAmountMl: Double = 0
    var totalExpenseAmount: Double = 0
    var expenseCategoryRaw: String = ExpenseCategory.other.rawValue
    var currencyCode: String = ""
    var allocationModeRaw: String = SharedCareAllocationMode.equal.rawValue
    var foodKindRaw: String = FeedFoodKind.dry.rawValue
    var stockOwnerPetId: String = ""
    var primaryLegacyModelName: String = ""
    var primaryLegacyModelId: String = ""
    var note: String = ""
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        actionKind: SharedCareActionKind = .feeding,
        executorId: String? = nil,
        sourcePetId: String = "",
        targetPetIds: [String] = [],
        species: String = "",
        totalAmountGrams: Double = 0,
        totalAmountMl: Double = 0,
        totalExpenseAmount: Double = 0,
        expenseCategory: ExpenseCategory = .other,
        currencyCode: String = "",
        allocationMode: SharedCareAllocationMode = .equal,
        foodKind: FeedFoodKind = .dry,
        stockOwnerPetId: String = "",
        primaryLegacyModelName: String = "",
        primaryLegacyModelId: String = "",
        note: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.actionKindRaw = actionKind.rawValue
        self.executorId = executorId
        self.sourcePetId = sourcePetId
        self.targetPetIdsRaw = targetPetIds.joined(separator: "|")
        self.speciesRaw = species
        self.totalAmountGrams = totalAmountGrams
        self.totalAmountMl = totalAmountMl
        self.totalExpenseAmount = totalExpenseAmount
        self.expenseCategoryRaw = expenseCategory.rawValue
        self.currencyCode = currencyCode
        self.allocationModeRaw = allocationMode.rawValue
        self.foodKindRaw = foodKind.rawValue
        self.stockOwnerPetId = stockOwnerPetId
        self.primaryLegacyModelName = primaryLegacyModelName
        self.primaryLegacyModelId = primaryLegacyModelId
        self.note = note
        self.createdAt = Date()
    }

    var actionKind: SharedCareActionKind { SharedCareActionKind(rawValue: actionKindRaw) ?? .feeding }
    var allocationMode: SharedCareAllocationMode { SharedCareAllocationMode(rawValue: allocationModeRaw) ?? .equal }
    var foodKind: FeedFoodKind { FeedFoodKind(rawValue: foodKindRaw) ?? .dry }
    var expenseCategory: ExpenseCategory { ExpenseCategory(rawValue: expenseCategoryRaw) ?? .other }
    var targetPetIds: [String] {
        targetPetIdsRaw
            .split(separator: "|")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

enum SharedPetTargetResolver {
    static func normalizedSpecies(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @MainActor
    static func normalizedTargets(_ targets: [Pet], fallback sourcePet: Pet) -> [Pet] {
        let candidates = targets.isEmpty ? [sourcePet] : targets
        var seen = Set<UUID>()
        var liveTargets = candidates.filter { pet in
            guard !pet.hasPassedAway, !seen.contains(pet.id) else { return false }
            seen.insert(pet.id)
            return true
        }
        if !sourcePet.hasPassedAway, !liveTargets.contains(where: { $0.id == sourcePet.id }) {
            liveTargets.insert(sourcePet, at: 0)
        }
        return liveTargets.sorted { lhs, rhs in
            if lhs.id == sourcePet.id { return true }
            if rhs.id == sourcePet.id { return false }
            return lhs.createdAt < rhs.createdAt
        }
    }

    @MainActor
    static func sameSpeciesTargets(sourcePet: Pet, allPets: [Pet], explicitTargetIds: Set<UUID> = []) -> [Pet] {
        let species = normalizedSpecies(sourcePet.species)
        let sameSpecies = allPets.filter { pet in
            !pet.hasPassedAway && normalizedSpecies(pet.species) == species
        }
        let selected = explicitTargetIds.isEmpty ? sameSpecies : sameSpecies.filter { explicitTargetIds.contains($0.id) }
        return normalizedTargets(selected, fallback: sourcePet)
    }
}

enum SharedPetChildLogStrategy {
    case care(type: CareType)
    case unknownPotty(type: PottyType)
    case expense(category: ExpenseCategory, note: String)
    case walk(distanceMeters: Double, endDate: Date?, coconutsEarned: Int, behaviorNotes: String?, moodRating: Int)
}

struct SharedPetActionDescriptor {
    let actionKind: SharedCareActionKind
    let sourcePet: Pet
    let targets: [Pet]
    let date: Date
    let executorId: String?
    let allocationMode: SharedCareAllocationMode
    let totalAmountGrams: Double
    let totalAmountMl: Double
    let foodKind: FeedFoodKind
    let stockOwnerPet: Pet?
    let totalExpenseAmount: Double
    let currencyCode: String
    let note: String
    let childLogStrategy: SharedPetChildLogStrategy
    let reward: QuestManager.OhanaActionType?
    let rewardQuality: QuestManager.QualityBonus
    let rewardTitle: String?
    let reminderCareType: CareType?
    let source: CareLedgerSource

    init(
        actionKind: SharedCareActionKind,
        sourcePet: Pet,
        targets: [Pet],
        date: Date = Date(),
        executorId: String? = nil,
        allocationMode: SharedCareAllocationMode = .equal,
        totalAmountGrams: Double = 0,
        totalAmountMl: Double = 0,
        foodKind: FeedFoodKind = .dry,
        stockOwnerPet: Pet? = nil,
        totalExpenseAmount: Double = 0,
        currencyCode: String = "",
        note: String = "",
        childLogStrategy: SharedPetChildLogStrategy,
        reward: QuestManager.OhanaActionType? = nil,
        rewardQuality: QuestManager.QualityBonus = .none,
        rewardTitle: String? = nil,
        reminderCareType: CareType? = nil,
        source: CareLedgerSource = .quickAction
    ) {
        self.actionKind = actionKind
        self.sourcePet = sourcePet
        self.targets = targets
        self.date = date
        self.executorId = executorId
        self.allocationMode = allocationMode
        self.totalAmountGrams = totalAmountGrams
        self.totalAmountMl = totalAmountMl
        self.foodKind = foodKind
        self.stockOwnerPet = stockOwnerPet
        self.totalExpenseAmount = totalExpenseAmount
        self.currencyCode = currencyCode
        self.note = note
        self.childLogStrategy = childLogStrategy
        self.reward = reward
        self.rewardQuality = rewardQuality
        self.rewardTitle = rewardTitle
        self.reminderCareType = reminderCareType
        self.source = source
    }
}

struct SharedPetActionResult {
    let sessionID: UUID
    let targetPetIDs: [UUID]
    let careLogIDs: [UUID]
    let pottyLogID: UUID?
    let pottyLog: PetPottyLog?
    let expenseLogIDs: [UUID]
    let walkLogIDs: [UUID]
    let reward: (humanGot: Int, petGot: Int)

    var coconutDelta: Int { max(0, reward.humanGot) + max(0, reward.petGot) }
}

enum SharedPetActionRecorder {
    @discardableResult
    @MainActor
    static func record(_ descriptor: SharedPetActionDescriptor, context: ModelContext) -> SharedPetActionResult {
        let targets = SharedPetTargetResolver.normalizedTargets(descriptor.targets, fallback: descriptor.sourcePet)
        let allocationTargetCount = max(targets.count, 1)
        let session = SharedCareSession(
            date: descriptor.date,
            actionKind: descriptor.actionKind,
            executorId: descriptor.executorId,
            sourcePetId: descriptor.sourcePet.id.uuidString,
            targetPetIds: targets.map { $0.id.uuidString },
            species: descriptor.sourcePet.species,
            totalAmountGrams: descriptor.totalAmountGrams,
            totalAmountMl: descriptor.totalAmountMl,
            totalExpenseAmount: descriptor.totalExpenseAmount,
            expenseCategory: expenseCategory(for: descriptor.childLogStrategy),
            currencyCode: descriptor.currencyCode,
            allocationMode: descriptor.allocationMode,
            foodKind: descriptor.foodKind,
            stockOwnerPetId: descriptor.stockOwnerPet?.id.uuidString ?? "",
            note: descriptor.note
        )
        context.insert(session)

        var careLogs: [(Pet, PetCareLog)] = []
        var expenseLogs: [(Pet, PetExpenseLog)] = []
        var walkLogs: [(Pet, PetWalkLog)] = []
        var pottyLog: PetPottyLog?

        switch descriptor.childLogStrategy {
        case .care(let type):
            let prefix = SharedCareMetadata.prefix(for: descriptor.actionKind)
            let perPetGrams = descriptor.totalAmountGrams > 0 ? descriptor.totalAmountGrams / Double(allocationTargetCount) : 0
            let perPetMl = descriptor.totalAmountMl > 0 ? descriptor.totalAmountMl / Double(allocationTargetCount) : 0
            for target in targets {
                let isStockOwner = descriptor.stockOwnerPet?.id == target.id
                let log = PetCareLog(
                    date: descriptor.date,
                    type: type,
                    amountGrams: type == .feeding ? perPetGrams : 0,
                    amountMl: type == .watering ? perPetMl : 0,
                    note: SharedCareMetadata.note(
                        prefix: prefix,
                        sessionId: session.id,
                        stockTotalGrams: isStockOwner ? descriptor.totalAmountGrams : nil,
                        isStockOwner: isStockOwner
                    ),
                    foodKind: descriptor.foodKind,
                    sharedSessionId: session.id.uuidString,
                    pet: target,
                    executorId: descriptor.executorId
                )
                context.insert(log)
                careLogs.append((target, log))
            }
        case .unknownPotty(let type):
            let log = PetPottyLog(
                date: descriptor.date,
                type: type,
                pet: nil,
                executorId: descriptor.executorId,
                sharedSessionId: session.id.uuidString
            )
            context.insert(log)
                pottyLog = log
        case .expense(let category, let note):
            let perPetAmount = descriptor.totalExpenseAmount > 0 ? descriptor.totalExpenseAmount / Double(allocationTargetCount) : 0
            for target in targets {
                let log = PetExpenseLog(
                    date: descriptor.date,
                    amount: perPetAmount,
                    category: category,
                    note: note,
                    pet: target,
                    executorId: descriptor.executorId,
                    sharedSessionId: session.id.uuidString
                )
                context.insert(log)
                expenseLogs.append((target, log))
            }
        case .walk(let distanceMeters, let endDate, let coconutsEarned, let behaviorNotes, let moodRating):
            for target in targets {
                let log = PetWalkLog(startDate: descriptor.date, pet: target, executorId: descriptor.executorId, sharedSessionId: session.id.uuidString)
                log.endDate = endDate
                log.distanceMeters = max(0, distanceMeters)
                log.coconutsEarned = max(0, coconutsEarned)
                log.behaviorNotes = behaviorNotes
                log.moodRating = moodRating
                context.insert(log)
                walkLogs.append((target, log))
            }
        }

        if let primary = primaryLegacyModel(careLogs: careLogs, pottyLog: pottyLog, expenseLogs: expenseLogs, walkLogs: walkLogs) {
            session.primaryLegacyModelName = primary.name
            session.primaryLegacyModelId = primary.id
        }
        context.safeSave()

        let reward: (humanGot: Int, petGot: Int)
        if let rewardType = descriptor.reward {
            reward = CoconutEconomyService.awardSharedCareAction(
                type: rewardType,
                pets: targets,
                context: context,
                quality: descriptor.rewardQuality,
                title: descriptor.rewardTitle
            )
            OasisUpgradeRewardService.rewardFeaturedCritterFromCare(type: rewardType, context: context)
        } else {
            reward = (0, 0)
        }

        recordLedger(
            descriptor: descriptor,
            session: session,
            targets: targets,
            careLogs: careLogs,
            pottyLog: pottyLog,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs,
            reward: reward,
            context: context
        )
        CareLedgerService.syncOasisTreeEnergyIfNeeded(
            metadataJSON: CareLedgerService.rewardMetadata(reward),
            context: context
        )

        if let careType = descriptor.reminderCareType {
            targets.forEach {
                QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
                    pet: $0,
                    type: careType,
                    context: context,
                    executorId: descriptor.executorId,
                    now: descriptor.date
                )
            }
        }

        publishRevision(
            descriptor: descriptor,
            session: session,
            targets: targets,
            careLogs: careLogs.map { $0.1 },
            pottyLog: pottyLog,
            expenseLogs: expenseLogs.map { $0.1 },
            walkLogs: walkLogs.map { $0.1 }
        )

        return SharedPetActionResult(
            sessionID: session.id,
            targetPetIDs: targets.map(\.id),
            careLogIDs: careLogs.map { $0.1.id },
            pottyLogID: pottyLog?.id,
            pottyLog: pottyLog,
            expenseLogIDs: expenseLogs.map { $0.1.id },
            walkLogIDs: walkLogs.map { $0.1.id },
            reward: reward
        )
    }

    @MainActor
    private static func publishRevision(
        descriptor: SharedPetActionDescriptor,
        session: SharedCareSession,
        targets: [Pet],
        careLogs: [PetCareLog],
        pottyLog: PetPottyLog?,
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) {
        var affected = Set(targets.map(\.id))
        affected.insert(session.id)
        careLogs.forEach { affected.insert($0.id) }
        if let pottyLog { affected.insert(pottyLog.id) }
        expenseLogs.forEach { affected.insert($0.id) }
        walkLogs.forEach { affected.insert($0.id) }
        ReadModelRevisionCenter.shared.publishDomainMutation(
            command: .quickCare(
                entityID: descriptor.sourcePet.id,
                action: "shared.\(descriptor.actionKind.rawValue)"
            ),
            affectedEntityIDs: affected,
            wroteBusinessFact: true,
            note: "sharedPetAction.\(descriptor.actionKind.rawValue)"
        )
    }

    private static func expenseCategory(for strategy: SharedPetChildLogStrategy) -> ExpenseCategory {
        if case .expense(let category, _) = strategy { return category }
        return .other
    }

    private static func primaryLegacyModel(
        careLogs: [(Pet, PetCareLog)],
        pottyLog: PetPottyLog?,
        expenseLogs: [(Pet, PetExpenseLog)],
        walkLogs: [(Pet, PetWalkLog)]
    ) -> (name: String, id: String)? {
        if let log = careLogs.first?.1 { return ("PetCareLog", log.id.uuidString) }
        if let pottyLog { return ("PetPottyLog", pottyLog.id.uuidString) }
        if let log = expenseLogs.first?.1 { return ("PetExpenseLog", log.id.uuidString) }
        if let log = walkLogs.first?.1 { return ("PetWalkLog", log.id.uuidString) }
        return nil
    }

    @MainActor
    private static func recordLedger(
        descriptor: SharedPetActionDescriptor,
        session: SharedCareSession,
        targets: [Pet],
        careLogs: [(Pet, PetCareLog)],
        pottyLog: PetPottyLog?,
        expenseLogs: [(Pet, PetExpenseLog)],
        walkLogs: [(Pet, PetWalkLog)],
        reward: (humanGot: Int, petGot: Int),
        context: ModelContext
    ) {
        let metadata = rewardMetadata(reward, sessionID: session.id, targetCount: targets.count)
        for (index, pair) in careLogs.enumerated() {
            CareLedgerService.recordPetCare(
                log: pair.1,
                pet: pair.0,
                source: descriptor.source,
                coconutDelta: index == 0 ? CareLedgerService.rewardDelta(reward) : 0,
                metadataJSON: index == 0 ? metadata : sharedMetadata(sessionID: session.id, targetCount: targets.count),
                context: context
            )
        }

        if let pottyLog {
            CareLedgerService.record(
                occurredAt: descriptor.date,
                actorKind: descriptor.executorId == nil ? .unknown : .human,
                actorId: descriptor.executorId,
                subjectKind: .unknown,
                subjectId: nil,
                eventKind: .potty,
                actionType: pottyLog.pottyType.rawValue,
                note: SharedCareMetadata.note(prefix: SharedCareMetadata.unknownPottyNotePrefix, sessionId: session.id),
                source: descriptor.source,
                legacyModelName: "PetPottyLog",
                legacyModelId: pottyLog.id.uuidString,
                metadataJSON: sharedMetadata(sessionID: session.id, targetCount: targets.count),
                context: context
            )
        }

        for (index, pair) in expenseLogs.enumerated() {
            CareLedgerService.record(
                occurredAt: pair.1.date,
                actorKind: pair.1.executorId == nil ? .unknown : .human,
                actorId: pair.1.executorId,
                subjectKind: .pet,
                subjectId: pair.0.id.uuidString,
                eventKind: .expense,
                actionType: pair.1.category,
                amountValue: pair.1.amount,
                amountUnit: descriptor.currencyCode,
                note: pair.1.note,
                source: descriptor.source,
                legacyModelName: "PetExpenseLog",
                legacyModelId: pair.1.id.uuidString,
                coconutDelta: index == 0 ? CareLedgerService.rewardDelta(reward) : 0,
                metadataJSON: index == 0 ? metadata : sharedMetadata(sessionID: session.id, targetCount: targets.count),
                context: context
            )
        }

        for (index, pair) in walkLogs.enumerated() {
            CareLedgerService.record(
                occurredAt: pair.1.startDate,
                actorKind: pair.1.executorId == nil ? .unknown : .human,
                actorId: pair.1.executorId,
                subjectKind: .pet,
                subjectId: pair.0.id.uuidString,
                eventKind: .walk,
                actionType: "walk",
                amountValue: pair.1.distanceMeters,
                amountUnit: "m",
                note: pair.1.behaviorNotes ?? "",
                source: descriptor.source,
                legacyModelName: "PetWalkLog",
                legacyModelId: pair.1.id.uuidString,
                coconutDelta: index == 0 ? CareLedgerService.rewardDelta(reward) : 0,
                metadataJSON: index == 0 ? metadata : sharedMetadata(sessionID: session.id, targetCount: targets.count),
                context: context
            )
        }
    }

    private static func rewardMetadata(_ reward: (humanGot: Int, petGot: Int), sessionID: UUID, targetCount: Int) -> String {
        let rewardJSON = CareLedgerService.rewardMetadata(reward)
        guard !rewardJSON.isEmpty,
              var object = try? JSONSerialization.jsonObject(with: Data(rewardJSON.utf8)) as? [String: Any] else {
            return sharedMetadata(sessionID: sessionID, targetCount: targetCount)
        }
        object["sharedSessionId"] = sessionID.uuidString
        object["targets"] = targetCount
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return sharedMetadata(sessionID: sessionID, targetCount: targetCount)
        }
        return json
    }

    private static func sharedMetadata(sessionID: UUID, targetCount: Int) -> String {
        "{\"sharedSessionId\":\"\(sessionID.uuidString)\",\"targets\":\(targetCount)}"
    }
}
