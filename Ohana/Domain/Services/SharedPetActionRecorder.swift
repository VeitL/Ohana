//
//  SharedPetActionRecorder.swift
//  Ohana
//
//  Domain write service for one action applied to multiple pets.
//

import Foundation
import SwiftData

enum SharedPetSelectionMemory {
    @MainActor
    static func restoredSelection(
        sourcePet: Pet,
        scope: String,
        candidates: [Pet],
        defaultToAll: Bool
    ) -> Set<UUID> {
        let candidateIDs = Set(candidates.map(\.id))
        guard let stored = UserDefaults.standard.array(forKey: storageKey(sourcePet: sourcePet, scope: scope)) as? [String],
              !stored.isEmpty else {
            return defaultSelection(sourcePet: sourcePet, candidates: candidates, defaultToAll: defaultToAll)
        }

        var restored = Set(stored.compactMap(UUID.init(uuidString:))).intersection(candidateIDs)
        if candidateIDs.contains(sourcePet.id) {
            restored.insert(sourcePet.id)
        }
        return restored.isEmpty
            ? defaultSelection(sourcePet: sourcePet, candidates: candidates, defaultToAll: defaultToAll)
            : restored
    }

    @MainActor
    static func saveSelection(
        _ selectedPetIds: Set<UUID>,
        sourcePet: Pet,
        scope: String,
        candidates: [Pet]
    ) {
        let candidateIDs = Set(candidates.map(\.id))
        guard !candidateIDs.isEmpty else { return }
        var normalized = selectedPetIds.intersection(candidateIDs)
        if candidateIDs.contains(sourcePet.id) {
            normalized.insert(sourcePet.id)
        }
        let encoded = normalized
            .map(\.uuidString)
            .sorted()
        UserDefaults.standard.set(encoded, forKey: storageKey(sourcePet: sourcePet, scope: scope))
    }

    @MainActor
    private static func defaultSelection(sourcePet: Pet, candidates: [Pet], defaultToAll: Bool) -> Set<UUID> {
        if defaultToAll {
            return Set(candidates.map(\.id))
        }
        return Set(candidates.contains(where: { $0.id == sourcePet.id }) ? [sourcePet.id] : [])
    }

    @MainActor
    private static func storageKey(sourcePet: Pet, scope: String) -> String {
        "sharedPetSelection.\(scope).\(sourcePet.id.uuidString)"
    }
}

enum SharedPetChildLogStrategy {
    case care(type: CareType)
    case potty(type: PottyType)
    case unknownPotty(type: PottyType)
    case hygiene(type: HygieneType)
    case expense(category: ExpenseCategory, note: String)
    case walk(distanceMeters: Double, endDate: Date?, coconutsEarned: Int, behaviorNotes: String?, moodRating: Int)
}

struct SharedPetActionDescriptor {
    let actionKind: SharedCareActionKind
    let sourcePet: Pet
    let targets: [Pet]
    let date: Date
    let executorId: String?
    let executorIds: [String]
    let allocationMode: SharedCareAllocationMode
    let totalAmountGrams: Double
    let totalAmountMl: Double
    let foodKind: FeedFoodKind
    let stockOwnerPet: Pet?
    let totalExpenseAmount: Double
    let currencyCode: String
    let note: String
    let childLogStrategy: SharedPetChildLogStrategy
    let reward: DomainCareRewardAction?
    let rewardQuality: DomainCareRewardQuality
    let rewardTitle: String?
    let reminderCareType: CareType?
    let source: CareLedgerSource

    init(
        actionKind: SharedCareActionKind,
        sourcePet: Pet,
        targets: [Pet],
        date: Date = Date(),
        executorId: String? = nil,
        executorIds: [String] = [],
        allocationMode: SharedCareAllocationMode = .equal,
        totalAmountGrams: Double = 0,
        totalAmountMl: Double = 0,
        foodKind: FeedFoodKind = .dry,
        stockOwnerPet: Pet? = nil,
        totalExpenseAmount: Double = 0,
        currencyCode: String = "",
        note: String = "",
        childLogStrategy: SharedPetChildLogStrategy,
        reward: DomainCareRewardAction? = nil,
        rewardQuality: DomainCareRewardQuality = .none,
        rewardTitle: String? = nil,
        reminderCareType: CareType? = nil,
        source: CareLedgerSource = .quickAction
    ) {
        self.actionKind = actionKind
        self.sourcePet = sourcePet
        self.targets = targets
        self.date = date
        let normalizedExecutorIds = SharedCareParticipantIDs.normalized(executorIds, preferredFirst: executorId)
        self.executorId = normalizedExecutorIds.first ?? executorId
        self.executorIds = normalizedExecutorIds
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
    let pottyLogIDs: [UUID]
    let pottyLogID: UUID?
    let pottyLog: PetPottyLog?
    let hygieneLogIDs: [UUID]
    let expenseLogIDs: [UUID]
    let walkLogIDs: [UUID]
    let walkLogs: [PetWalkLog]
    let reward: (humanGot: Int, petGot: Int)
    let disposition: CareFactWriteDisposition

    init(
        sessionID: UUID,
        targetPetIDs: [UUID],
        careLogIDs: [UUID],
        pottyLogIDs: [UUID] = [],
        pottyLogID: UUID?,
        pottyLog: PetPottyLog?,
        hygieneLogIDs: [UUID] = [],
        expenseLogIDs: [UUID],
        walkLogIDs: [UUID],
        walkLogs: [PetWalkLog],
        reward: (humanGot: Int, petGot: Int),
        disposition: CareFactWriteDisposition
    ) {
        self.sessionID = sessionID
        self.targetPetIDs = targetPetIDs
        self.careLogIDs = careLogIDs
        self.pottyLogIDs = pottyLogIDs
        self.pottyLogID = pottyLogID
        self.pottyLog = pottyLog
        self.hygieneLogIDs = hygieneLogIDs
        self.expenseLogIDs = expenseLogIDs
        self.walkLogIDs = walkLogIDs
        self.walkLogs = walkLogs
        self.reward = reward
        self.disposition = disposition
    }

    var coconutDelta: Int { max(0, reward.humanGot) + max(0, reward.petGot) }

    var didWriteFact: Bool {
        disposition.didWriteFact
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }

    static func noOp() -> SharedPetActionResult {
        SharedPetActionResult(
            sessionID: UUID(),
            targetPetIDs: [],
            careLogIDs: [],
            pottyLogID: nil,
            pottyLog: nil,
            expenseLogIDs: [],
            walkLogIDs: [],
            walkLogs: [],
            reward: (0, 0),
            disposition: .noOp
        )
    }
}

enum SharedPetActionRecorder {
    @discardableResult
    @MainActor
    static func record(
        _ descriptor: SharedPetActionDescriptor,
        context: ModelContext,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? .live()
        let targets = SharedPetTargetResolver.normalizedTargets(descriptor.targets, fallback: descriptor.sourcePet)
        guard !targets.isEmpty else {
            return .noOp()
        }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: descriptor.executorId,
            context: context,
            logPrefix: "SharedPetActionRecorder.record"
        )
        let effectiveExecutorIds = SharedCareParticipantIDs.normalized(
            descriptor.executorIds,
            preferredFirst: actor.effectiveExecutorId ?? descriptor.executorId
        )
        let allocationTargetCount = max(targets.count, 1)
        let visibleDescriptorNote = SharedCareMetadata.userNoteForStorage(descriptor.note)
        let session = SharedCareSession(
            date: descriptor.date,
            actionKind: descriptor.actionKind,
            executorId: actor.effectiveExecutorId,
            executorIds: effectiveExecutorIds,
            sourcePetId: descriptor.sourcePet.id.uuidString,
            targetPetIds: targets.map(\.id.uuidString),
            species: descriptor.sourcePet.species,
            totalAmountGrams: descriptor.totalAmountGrams,
            totalAmountMl: descriptor.totalAmountMl,
            totalExpenseAmount: descriptor.totalExpenseAmount,
            expenseCategory: expenseCategory(for: descriptor.childLogStrategy),
            currencyCode: descriptor.currencyCode,
            allocationMode: descriptor.allocationMode,
            foodKind: descriptor.foodKind,
            stockOwnerPetId: descriptor.stockOwnerPet?.id.uuidString ?? "",
            note: visibleDescriptorNote
        )

        var careLogs: [(Pet, PetCareLog)] = []
        var pottyLogs: [(Pet, PetPottyLog)] = []
        var hygieneLogs: [(Pet, PetHygieneLog)] = []
        var expenseLogs: [(Pet, PetExpenseLog)] = []
        var walkLogs: [(Pet, PetWalkLog)] = []
        var pottyLog: PetPottyLog?
        var effectPlans: [AuthorizedDomainCareFactWrite] = []

        switch descriptor.childLogStrategy {
        case let .care(type):
            let perPetGrams = distributedAmount(descriptor.totalAmountGrams, count: allocationTargetCount, fractionDigits: 0)
            let perPetMl = distributedAmount(descriptor.totalAmountMl, count: allocationTargetCount, fractionDigits: 0)
            for (index, target) in targets.enumerated() {
                let intent = DomainCareFactCreateIntent(
                    kind: .care(
                        type: type,
                        amountGrams: type == .feeding ? perPetGrams[index] : 0,
                        amountMl: type == .watering ? perPetMl[index] : 0,
                        note: visibleDescriptorNote,
                        foodKind: descriptor.foodKind,
                        treatKind: nil,
                        autoFeedDedupKey: "",
                        sharedSessionId: session.id.uuidString
                    ),
                    occurredAt: descriptor.date,
                    executorId: descriptor.executorId
                )
                guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                    pet: target,
                    intent: intent,
                    context: context,
                    logPrefix: "SharedPetActionRecorder.record",
                    actorOverride: actor
                ) else { continue }
                let log = DomainCareFactWriter.createCareLog(plan: write, context: context).log
                careLogs.append((target, log))
                effectPlans.append(write)
            }
        case let .potty(type):
            for target in targets {
                let intent = DomainCareFactCreateIntent(
                    kind: .potty(type: type, sharedSessionId: session.id.uuidString),
                    occurredAt: descriptor.date,
                    executorId: descriptor.executorId
                )
                guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                    pet: target,
                    intent: intent,
                    context: context,
                    logPrefix: "SharedPetActionRecorder.record",
                    actorOverride: actor
                ) else { continue }
                let log = DomainCareFactWriter.createPottyLog(plan: write, context: context)
                pottyLogs.append((target, log))
                effectPlans.append(write)
            }
        case let .unknownPotty(type):
            let intent = DomainCareFactCreateIntent(
                kind: .unknownPotty(type: type, sharedSessionId: session.id.uuidString),
                occurredAt: descriptor.date,
                executorId: descriptor.executorId
            )
            if let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                pet: descriptor.sourcePet,
                intent: intent,
                context: context,
                logPrefix: "SharedPetActionRecorder.record",
                actorOverride: actor
            ) {
                pottyLog = DomainCareFactWriter.createUnknownPottyLog(plan: write, context: context)
                effectPlans.append(write)
            }
        case let .hygiene(type):
            for target in targets {
                let intent = DomainCareFactCreateIntent(
                    kind: .hygiene(type: type, sharedSessionId: session.id.uuidString),
                    occurredAt: descriptor.date,
                    executorId: descriptor.executorId
                )
                guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                    pet: target,
                    intent: intent,
                    context: context,
                    logPrefix: "SharedPetActionRecorder.record",
                    actorOverride: actor
                ) else { continue }
                let log = DomainCareFactWriter.createHygieneLog(plan: write, context: context)
                hygieneLogs.append((target, log))
                effectPlans.append(write)
            }
        case let .expense(category, note):
            let visibleExpenseNote = SharedCareMetadata.userNoteForStorage(note)
            let perPetAmounts = distributedAmount(descriptor.totalExpenseAmount, count: allocationTargetCount, fractionDigits: 2)
            for (index, target) in targets.enumerated() {
                let intent = DomainCareFactCreateIntent(
                    kind: .expense(
                        amount: perPetAmounts[index],
                        category: category,
                        note: visibleExpenseNote,
                        sharedSessionId: session.id.uuidString
                    ),
                    occurredAt: descriptor.date,
                    executorId: descriptor.executorId
                )
                guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                    pet: target,
                    intent: intent,
                    context: context,
                    logPrefix: "SharedPetActionRecorder.record",
                    actorOverride: actor
                ) else { continue }
                let log = DomainCareFactWriter.createExpenseLog(plan: write, context: context)
                expenseLogs.append((target, log))
                effectPlans.append(write)
            }
        case let .walk(distanceMeters, endDate, coconutsEarned, behaviorNotes, moodRating):
            for target in targets {
                let intent = DomainCareFactCreateIntent(
                    kind: .walk(
                        distanceMeters: distanceMeters,
                        endDate: endDate,
                        coconutsEarned: coconutsEarned,
                        behaviorNotes: behaviorNotes,
                        moodRating: moodRating,
                        executorIds: effectiveExecutorIds,
                        sharedSessionId: session.id.uuidString
                    ),
                    occurredAt: descriptor.date,
                    executorId: descriptor.executorId
                )
                guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                    pet: target,
                    intent: intent,
                    context: context,
                    logPrefix: "SharedPetActionRecorder.record",
                    actorOverride: actor
                ) else { continue }
                let log = DomainCareFactWriter.createWalkLog(plan: write, context: context)
                walkLogs.append((target, log))
                effectPlans.append(write)
            }
        }

        guard !careLogs.isEmpty || !pottyLogs.isEmpty || pottyLog != nil || !hygieneLogs.isEmpty || !expenseLogs.isEmpty || !walkLogs.isEmpty else {
            return .noOp()
        }
        let writtenTargets = writtenTargets(
            sourcePet: descriptor.sourcePet,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            pottyLog: pottyLog,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )
        let sessionTargets: [Pet] = if case .unknownPotty = descriptor.childLogStrategy {
            targets
        } else {
            writtenTargets
        }
        session.sourcePetId = writtenTargets.first(where: { $0.id == descriptor.sourcePet.id })?.id.uuidString
            ?? writtenTargets.first?.id.uuidString
            ?? descriptor.sourcePet.id.uuidString
        session.targetPetIdsRaw = sessionTargets.map(\.id.uuidString).joined(separator: "|")
        session.speciesRaw = sessionTargets.first?.species ?? descriptor.sourcePet.species
        context.insert(session)

        if let primary = primaryLegacyModel(
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            pottyLog: pottyLog,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        ) {
            session.primaryLegacyModelName = primary.name
            session.primaryLegacyModelId = primary.id
        }
        CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: descriptor.date)
        context.safeSave()

        let reward: (humanGot: Int, petGot: Int) = DomainCareFactEffectsDispatcher.map(plans: effectPlans, default: (humanGot: 0, petGot: 0)) { actor in
            if let rewardType = descriptor.reward {
                return dependencies.economy.awardSharedCareAction(
                    type: rewardType,
                    pets: writtenTargets,
                    context: context,
                    quality: descriptor.rewardQuality,
                    title: descriptor.rewardTitle,
                    executorId: actor.rewardExecutorId
                )
            }
            return (humanGot: 0, petGot: 0)
        }

        DomainCareFactEffectsDispatcher.run(plans: effectPlans) { actor in
            if !walkLogs.isEmpty {
                let actualWalkCoconuts = max(0, reward.humanGot + reward.petGot)
                for (index, pair) in walkLogs.enumerated() {
                    pair.1.coconutsEarned = index == 0 ? actualWalkCoconuts : 0
                }
                CloudSyncMutationRecorder.markModified(walkLogs.map(\.1), context: context, modifiedAt: descriptor.date)
            }

            recordLedger(
                descriptor: descriptor,
                session: session,
                targets: sessionTargets,
                careLogs: careLogs,
                pottyLogs: pottyLogs,
                pottyLog: pottyLog,
                hygieneLogs: hygieneLogs,
                expenseLogs: expenseLogs,
                walkLogs: walkLogs,
                reward: reward,
                context: context,
                dependencies: dependencies
            )
            dependencies.careLedger.syncLedgerEnergyIfNeeded(
                metadataJSON: dependencies.economy.rewardMetadata(for: reward),
                context: context
            )

            if let careType = descriptor.reminderCareType {
                for target in writtenTargets {
                    dependencies.quickActionReminderCompletion.completeNearestPetCareReminder(
                        pet: target,
                        type: careType,
                        context: context,
                        executorId: actor.effectiveExecutorId,
                        now: descriptor.date
                    )
                }
            }
            if !pottyLogs.isEmpty {
                for pair in pottyLogs {
                    dependencies.quickActionReminderCompletion.completeNearestPetPottyReminder(
                        pet: pair.0,
                        context: context,
                        executorId: actor.effectiveExecutorId,
                        now: descriptor.date
                    )
                }
            }
            if case let .hygiene(type) = descriptor.childLogStrategy {
                for pair in hygieneLogs {
                    dependencies.quickActionReminderCompletion.completeNearestPetHygieneReminder(
                        pet: pair.0,
                        type: type,
                        context: context,
                        executorId: actor.effectiveExecutorId,
                        now: descriptor.date
                    )
                }
            }

            deriveRevision(
                descriptor: descriptor,
                session: session,
                targets: sessionTargets,
                careLogs: careLogs.map(\.1),
                pottyLogs: pottyLogs.map(\.1),
                pottyLog: pottyLog,
                hygieneLogs: hygieneLogs.map(\.1),
                expenseLogs: expenseLogs.map(\.1),
                walkLogs: walkLogs.map(\.1),
                reward: reward,
                derivations: CareDerivationExecutor(revisions: dependencies.revisions)
            )
        }

        return SharedPetActionResult(
            sessionID: session.id,
            targetPetIDs: sessionTargets.map(\.id),
            careLogIDs: careLogs.map(\.1.id),
            pottyLogIDs: pottyLogs.map(\.1.id),
            pottyLogID: pottyLog?.id,
            pottyLog: pottyLog,
            hygieneLogIDs: hygieneLogs.map(\.1.id),
            expenseLogIDs: expenseLogs.map(\.1.id),
            walkLogIDs: walkLogs.map(\.1.id),
            walkLogs: walkLogs.map(\.1),
            reward: reward,
            disposition: .active
        )
    }

    private static func writtenTargets(
        sourcePet: Pet,
        careLogs: [(Pet, PetCareLog)],
        pottyLogs: [(Pet, PetPottyLog)],
        pottyLog: PetPottyLog?,
        hygieneLogs: [(Pet, PetHygieneLog)],
        expenseLogs: [(Pet, PetExpenseLog)],
        walkLogs: [(Pet, PetWalkLog)]
    ) -> [Pet] {
        var result: [Pet] = []
        func append(_ pet: Pet) {
            guard !result.contains(where: { $0.id == pet.id }) else { return }
            result.append(pet)
        }

        careLogs.map(\.0).forEach(append)
        pottyLogs.map(\.0).forEach(append)
        hygieneLogs.map(\.0).forEach(append)
        expenseLogs.map(\.0).forEach(append)
        walkLogs.map(\.0).forEach(append)
        if pottyLog != nil {
            append(sourcePet)
        }
        return result
    }

    @MainActor
    private static func deriveRevision(
        descriptor: SharedPetActionDescriptor,
        session: SharedCareSession,
        targets: [Pet],
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        pottyLog: PetPottyLog?,
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog],
        reward: (humanGot: Int, petGot: Int),
        derivations: CareDerivationExecutor
    ) {
        var affected = Set(targets.map(\.id))
        affected.insert(session.id)
        careLogs.forEach { affected.insert($0.id) }
        pottyLogs.forEach { affected.insert($0.id) }
        if let pottyLog { affected.insert(pottyLog.id) }
        hygieneLogs.forEach { affected.insert($0.id) }
        expenseLogs.forEach { affected.insert($0.id) }
        walkLogs.forEach { affected.insert($0.id) }
        derivations.derive(
            .active(
                disposition: .active,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: descriptor.sourcePet.id,
                    logIDs: Array(affected),
                    factDate: descriptor.date,
                    operationDate: descriptor.date
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: .quickCare(
                        entityID: descriptor.sourcePet.id,
                        action: "shared.\(descriptor.actionKind.rawValue)"
                    ),
                    affectedEntityIDs: affected,
                    note: "sharedPetAction.\(descriptor.actionKind.rawValue)"
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: reward.humanGot,
                    petDelta: reward.petGot
                ),
                sharedSession: CareWriteOutcome.SharedSessionPayload(
                    sessionID: session.id,
                    sourcePetID: descriptor.sourcePet.id,
                    targetPetIDs: targets.map(\.id)
                )
            )
        )
    }

    private static func expenseCategory(for strategy: SharedPetChildLogStrategy) -> ExpenseCategory {
        if case let .expense(category, _) = strategy { return category }
        return .other
    }

    private static func distributedAmount(_ total: Double, count: Int, fractionDigits: Int) -> [Double] {
        guard total > 0, count > 0 else { return Array(repeating: 0, count: max(count, 0)) }
        let factor = pow(10, Double(fractionDigits))
        let totalUnits = Int((total * factor).rounded())
        let base = totalUnits / count
        let remainder = totalUnits % count
        return (0 ..< count).map { index in
            Double(base + (index < remainder ? 1 : 0)) / factor
        }
    }

    private static func primaryLegacyModel(
        careLogs: [(Pet, PetCareLog)],
        pottyLogs: [(Pet, PetPottyLog)],
        pottyLog: PetPottyLog?,
        hygieneLogs: [(Pet, PetHygieneLog)],
        expenseLogs: [(Pet, PetExpenseLog)],
        walkLogs: [(Pet, PetWalkLog)]
    ) -> (name: String, id: String)? {
        if let log = careLogs.first?.1 { return ("PetCareLog", log.id.uuidString) }
        if let log = pottyLogs.first?.1 { return ("PetPottyLog", log.id.uuidString) }
        if let pottyLog { return ("PetPottyLog", pottyLog.id.uuidString) }
        if let log = hygieneLogs.first?.1 { return ("PetHygieneLog", log.id.uuidString) }
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
        pottyLogs: [(Pet, PetPottyLog)],
        pottyLog: PetPottyLog?,
        hygieneLogs: [(Pet, PetHygieneLog)],
        expenseLogs: [(Pet, PetExpenseLog)],
        walkLogs: [(Pet, PetWalkLog)],
        reward: (humanGot: Int, petGot: Int),
        context: ModelContext,
        dependencies: CareEventServiceDependencies
    ) {
        let metadata = rewardMetadata(
            reward,
            sessionID: session.id,
            targetCount: targets.count,
            executorIds: descriptor.executorIds,
            economy: dependencies.economy
        )
        for (index, pair) in careLogs.enumerated() {
            dependencies.careLedger.recordPetCare(
                log: pair.1,
                pet: pair.0,
                source: descriptor.source,
                sourceEventId: nil,
                sourceReminderId: nil,
                coconutDelta: index == 0 ? dependencies.careLedger.rewardDelta(reward) : 0,
                metadataJSON: index == 0 ? metadata : sharedMetadata(
                    sessionID: session.id,
                    targetCount: targets.count,
                    executorIds: descriptor.executorIds
                ),
                context: context,
                save: true
            )
        }

        for (index, pair) in pottyLogs.enumerated() {
            dependencies.careLedger.recordPetPotty(
                log: pair.1,
                pet: pair.0,
                source: descriptor.source,
                coconutDelta: index == 0 ? dependencies.careLedger.rewardDelta(reward) : 0,
                metadataJSON: index == 0 ? metadata : sharedMetadata(
                    sessionID: session.id,
                    targetCount: targets.count,
                    executorIds: descriptor.executorIds
                ),
                context: context,
                save: true
            )
        }

        if let pottyLog {
            dependencies.careLedger.record(
                occurredAt: descriptor.date,
                actorKind: pottyLog.executorId == nil ? .unknown : .human,
                actorId: pottyLog.executorId,
                subjectKind: .unknown,
                subjectId: nil,
                eventKind: .potty,
                actionType: pottyLog.pottyType.rawValue,
                amountValue: 0,
                amountUnit: "",
                note: "",
                source: descriptor.source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetPottyLog",
                legacyModelId: pottyLog.id.uuidString,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: sharedMetadata(
                    sessionID: session.id,
                    targetCount: targets.count,
                    executorIds: descriptor.executorIds
                ),
                context: context,
                save: true
            )
        }

        for (index, pair) in hygieneLogs.enumerated() {
            dependencies.careLedger.record(
                occurredAt: pair.1.date,
                actorKind: pair.1.executorId == nil ? .unknown : .human,
                actorId: pair.1.executorId,
                subjectKind: .pet,
                subjectId: pair.0.id.uuidString,
                eventKind: .hygiene,
                actionType: pair.1.hygieneType.rawValue,
                amountValue: 0,
                amountUnit: "",
                note: "",
                source: descriptor.source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetHygieneLog",
                legacyModelId: pair.1.id.uuidString,
                coconutDelta: index == 0 ? dependencies.careLedger.rewardDelta(reward) : 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: index == 0 ? metadata : sharedMetadata(
                    sessionID: session.id,
                    targetCount: targets.count,
                    executorIds: descriptor.executorIds
                ),
                context: context,
                save: true
            )
        }

        for (index, pair) in expenseLogs.enumerated() {
            dependencies.careLedger.record(
                occurredAt: pair.1.date,
                actorKind: pair.1.executorId == nil ? .unknown : .human,
                actorId: pair.1.executorId,
                subjectKind: .pet,
                subjectId: pair.0.id.uuidString,
                eventKind: .expense,
                actionType: pair.1.category,
                amountValue: pair.1.amount,
                amountUnit: descriptor.currencyCode,
                note: SharedCareMetadata.visibleNote(pair.1.note),
                source: descriptor.source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetExpenseLog",
                legacyModelId: pair.1.id.uuidString,
                coconutDelta: index == 0 ? dependencies.careLedger.rewardDelta(reward) : 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: index == 0 ? metadata : sharedMetadata(
                    sessionID: session.id,
                    targetCount: targets.count,
                    executorIds: descriptor.executorIds
                ),
                context: context,
                save: true
            )
        }

        for (index, pair) in walkLogs.enumerated() {
            dependencies.careLedger.record(
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
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetWalkLog",
                legacyModelId: pair.1.id.uuidString,
                coconutDelta: index == 0 ? dependencies.careLedger.rewardDelta(reward) : 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: index == 0 ? metadata : sharedMetadata(
                    sessionID: session.id,
                    targetCount: targets.count,
                    executorIds: pair.1.executorIds
                ),
                context: context,
                save: true
            )
        }
    }

    private static func rewardMetadata(
        _ reward: (humanGot: Int, petGot: Int),
        sessionID: UUID,
        targetCount: Int,
        executorIds: [String],
        economy: CareEventEconomyAwarding
    ) -> String {
        let rewardJSON = economy.rewardMetadata(for: reward)
        guard !rewardJSON.isEmpty,
              var object = try? JSONSerialization.jsonObject(with: Data(rewardJSON.utf8)) as? [String: Any] else {
            return sharedMetadata(sessionID: sessionID, targetCount: targetCount, executorIds: executorIds)
        }
        object["sharedSessionId"] = sessionID.uuidString
        object["targets"] = targetCount
        if executorIds.count > 1 {
            object["executorIds"] = executorIds
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return sharedMetadata(sessionID: sessionID, targetCount: targetCount, executorIds: executorIds)
        }
        return json
    }

    private static func sharedMetadata(sessionID: UUID, targetCount: Int, executorIds: [String] = []) -> String {
        var object: [String: Any] = [
            "sharedSessionId": sessionID.uuidString,
            "targets": targetCount
        ]
        if executorIds.count > 1 {
            object["executorIds"] = executorIds
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"sharedSessionId\":\"\(sessionID.uuidString)\",\"targets\":\(targetCount)}"
        }
        return json
    }
}
