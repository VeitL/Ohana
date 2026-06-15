//
//  PetCareCommands.swift
//  Ohana
//
//  Domain write boundaries for pet care and potty tracking.
//

import Foundation
import SwiftData

struct PetCareTrackingCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID
    let linkedPottyLogID: UUID?
    let careType: CareType
    let coconutDelta: Int
    let occurredAt: Date
    let disposition: CareFactWriteDisposition

    var didRecord: Bool {
        disposition.didWriteFact
    }

    var allowsDerivedEffects: Bool {
        disposition.allowsDerivedEffects
    }
}

struct PetCareTrackingDeleteCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID
    let linkedPottyLogID: UUID?
    let removedLedgerEventIDs: [UUID]
    let didDelete: Bool
}

@MainActor
private func fetchPetCareCommandModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "PetCareCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

@MainActor
private func petCareCommandLedgerEvents(
    forLegacyModelName modelName: String,
    id: UUID,
    context: ModelContext
) -> [CareLedgerEvent] {
    let idString = id.uuidString
    let descriptor = FetchDescriptor<CareLedgerEvent>(
        predicate: #Predicate<CareLedgerEvent> { event in
            event.legacyModelName == modelName && event.legacyModelId == idString
        }
    )
    return fetchPetCareCommandModelsOrLog(
        descriptor,
        context: context,
        operation: "fetch ledger events for \(modelName)"
    )
}

enum PetCareTrackingCommandService {
    @discardableResult
    @MainActor
    static func recordCare(
        pet: Pet,
        type: CareType,
        amountGrams: Double = 0,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        careEvents providedCareEvents: CareEventRecording? = nil
    ) -> (result: PetCareTrackingCommandResult, log: PetCareLog) {
        let careEvents = providedCareEvents ?? CareEventService()
        if type == .feeding, amountGrams > 0 {
            let recorded = careEvents.recordManualFeedFact(
                pet: pet,
                amountGrams: amountGrams,
                context: context,
                executorId: executorId,
                quality: .none,
                date: date,
                foodKind: .dry,
                source: .detail
            )
            guard recorded.result.didWriteFact else {
                return (
                    PetCareTrackingCommandResult(
                        petID: pet.id,
                        careLogID: recorded.result.logID,
                        linkedPottyLogID: nil,
                        careType: .feeding,
                        coconutDelta: 0,
                        occurredAt: date,
                        disposition: recorded.result.disposition
                    ),
                    recorded.log
                )
            }
            return (
                PetCareTrackingCommandResult(
                    petID: pet.id,
                    careLogID: recorded.result.logID,
                    linkedPottyLogID: nil,
                    careType: .feeding,
                    coconutDelta: recorded.result.coconutDelta,
                    occurredAt: date,
                    disposition: recorded.result.disposition
                ),
                recorded.log
            )
        }

        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward(for: type, pet: pet),
            quality: .none,
            date: date,
            source: .detail,
            createsLinkedPottyLog: type == .litter
        )
        guard recorded.result.didWriteFact else {
            return (
                PetCareTrackingCommandResult(
                    petID: pet.id,
                    careLogID: recorded.result.logID,
                    linkedPottyLogID: nil,
                    careType: type,
                    coconutDelta: 0,
                    occurredAt: date,
                    disposition: recorded.result.disposition
                ),
                recorded.log
            )
        }
        return (
            PetCareTrackingCommandResult(
                petID: pet.id,
                careLogID: recorded.result.logID,
                linkedPottyLogID: recorded.result.linkedPottyLogID,
                careType: type,
                coconutDelta: recorded.result.coconutDelta,
                occurredAt: date,
                disposition: recorded.result.disposition
            ),
            recorded.log
        )
    }

    @discardableResult
    @MainActor
    static func deleteCareLog(
        _ log: PetCareLog,
        pet: Pet,
        context: ModelContext
    ) -> PetCareTrackingDeleteCommandResult {
        let careLogID = log.id
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsDerivedEffects else {
            return PetCareTrackingDeleteCommandResult(
                petID: pet.id,
                careLogID: careLogID,
                linkedPottyLogID: nil,
                removedLedgerEventIDs: [],
                didDelete: false
            )
        }
        guard log.pet?.id == pet.id else {
            return PetCareTrackingDeleteCommandResult(
                petID: pet.id,
                careLogID: careLogID,
                linkedPottyLogID: nil,
                removedLedgerEventIDs: [],
                didDelete: false
            )
        }
        let linkedPotty = linkedPottyLog(for: log, pet: pet, context: context)
        var removedLedgerEvents = ledgerEvents(forLegacyModelName: "PetCareLog", id: careLogID, context: context)
        if let linkedPotty {
            removedLedgerEvents += ledgerEvents(forLegacyModelName: "PetPottyLog", id: linkedPotty.id, context: context)
        }

        for event in removedLedgerEvents {
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        if let linkedPotty {
            CloudSyncMutationRecorder.markDeleted(linkedPotty, pet: pet, context: context)
            context.delete(linkedPotty)
        }
        let sharedSessionId = log.sharedSessionId
        CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context)
        context.delete(log)
        SharedCareSessionMaintenance.reconcileAfterDeletingChild(sharedSessionId: sharedSessionId, context: context)
        context.safeSave()

        return PetCareTrackingDeleteCommandResult(
            petID: pet.id,
            careLogID: careLogID,
            linkedPottyLogID: linkedPotty?.id,
            removedLedgerEventIDs: removedLedgerEvents.map(\.id),
            didDelete: true
        )
    }

    @MainActor
    private static func linkedPottyLog(for log: PetCareLog, pet: Pet, context: ModelContext) -> PetPottyLog? {
        guard log.careType == .litter else { return nil }
        let logs = fetchPetCareCommandModelsOrLog(
            FetchDescriptor<PetPottyLog>(),
            context: context,
            operation: "fetch linked potty logs"
        )
        return logs
            .filter { candidate in
                candidate.pet?.id == pet.id
                    && candidate.executorId == log.executorId
                    && abs(candidate.date.timeIntervalSince(log.date)) < 2
            }
            .min { lhs, rhs in
                abs(lhs.date.timeIntervalSince(log.date)) < abs(rhs.date.timeIntervalSince(log.date))
            }
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        petCareCommandLedgerEvents(forLegacyModelName: modelName, id: id, context: context)
    }

    private static func reward(for type: CareType, pet: Pet) -> QuestManager.OhanaActionType {
        switch type {
        case .feeding:
            .feed
        case .watering:
            .water
        case .litter:
            .potty(isLitter: true)
        case .play:
            .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            .general(humanReward: 25, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理鸟笼奖励")
        case .freeFlight:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 保湿打卡奖励")
        case .substrateChange:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 环境清洁奖励")
        case .waterChange:
            .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 换水奖励")
        }
    }
}

struct PetPottyDeleteCommandResult: Equatable {
    let petID: UUID
    let logID: UUID
    let removedLedgerEventIDs: [UUID]
    let didDelete: Bool
}

struct PetPottyClaimCommandResult: Equatable {
    let petID: UUID
    let logID: UUID
    let sharedSessionID: String
    let updatedLedgerEventIDs: [UUID]
}

enum PetPottyCommandService {
    @discardableResult
    @MainActor
    static func deletePottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPottyDeleteCommandResult {
        let logID = log.id
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsDerivedEffects else {
            return PetPottyDeleteCommandResult(
                petID: pet.id,
                logID: logID,
                removedLedgerEventIDs: [],
                didDelete: false
            )
        }
        guard canDeletePottyLog(log, from: pet) else {
            return PetPottyDeleteCommandResult(
                petID: pet.id,
                logID: logID,
                removedLedgerEventIDs: [],
                didDelete: false
            )
        }
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetPottyLog", id: logID, context: context)
        for event in ledgerEvents {
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        let sharedSessionId = log.sharedSessionId
        CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context)
        context.delete(log)
        SharedCareSessionMaintenance.reconcileAfterDeletingChild(sharedSessionId: sharedSessionId, context: context)
        context.safeSave()
        return PetPottyDeleteCommandResult(
            petID: pet.id,
            logID: logID,
            removedLedgerEventIDs: ledgerEvents.map(\.id),
            didDelete: true
        )
    }

    @discardableResult
    @MainActor
    static func claimUnknownPottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPottyClaimCommandResult {
        let sharedSessionId = log.sharedSessionId
        log.pet = pet

        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetPottyLog", id: log.id, context: context)
        for event in ledgerEvents {
            event.subjectKind = CareLedgerSubjectKind.pet.rawValue
            event.subjectId = pet.id.uuidString
            event.note = SharedCareMetadata.visibleNote(event.note)
        }
        SharedCareSessionMaintenance.reconcileAfterClaimingPotty(log, pet: pet, context: context)
        context.safeSave()

        return PetPottyClaimCommandResult(
            petID: pet.id,
            logID: log.id,
            sharedSessionID: sharedSessionId,
            updatedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        petCareCommandLedgerEvents(forLegacyModelName: modelName, id: id, context: context)
    }

    private static func canDeletePottyLog(_ log: PetPottyLog, from pet: Pet) -> Bool {
        if log.pet?.id == pet.id {
            return true
        }
        return log.pet == nil && !log.sharedSessionId.isEmpty
    }
}

@MainActor
struct PetCareCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    private let derivations: CareDerivationExecutor

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
        self.derivations = CareDerivationExecutor(revisions: revisions)
    }

    @discardableResult
    func recordCare(
        pet: Pet,
        type: CareType,
        amountGrams: Double = 0,
        amountMl: Double = 0,
        executorId: String? = nil,
        date: Date = Date(),
        note: String? = nil
    ) -> (result: PetCareTrackingCommandResult, log: PetCareLog) {
        let recorded = PetCareTrackingCommandService.recordCare(
            pet: pet,
            type: type,
            amountGrams: amountGrams,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            date: date
        )
        deriveCareRecord(recorded.result, note: note)
        return recorded
    }

    @discardableResult
    func deleteCareLog(
        _ log: PetCareLog,
        pet: Pet,
        note: String
    ) -> PetCareTrackingDeleteCommandResult {
        let result = PetCareTrackingCommandService.deleteCareLog(log, pet: pet, context: context)
        deriveCareDelete(result, note: note)
        return result
    }

    @discardableResult
    func deletePottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        note: String
    ) -> PetPottyDeleteCommandResult {
        let result = PetPottyCommandService.deletePottyLog(log, pet: pet, context: context)
        derivePottyDelete(result, note: note)
        return result
    }

    @discardableResult
    func claimUnknownPottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        note: String
    ) -> PetPottyClaimCommandResult {
        let result = PetPottyCommandService.claimUnknownPottyLog(log, pet: pet, context: context)
        derivations.derive(
            .derivedMutation(
                command: .quickCare(entityID: pet.id, action: "claimUnknownPotty"),
                affectedEntityIDs: [pet.id, log.id],
                note: note
            )
        )
        return result
    }

    @discardableResult
    func recordCatCare(
        pet: Pet,
        input: CatCareCommandInput,
        note: String = "catCare.record"
    ) -> CatCareCommandResult {
        let result = CatCareCommandService.record(pet: pet, input: input, context: context)
        deriveCatCareRecord(result, note: note)
        return result
    }

    @discardableResult
    func undoCatCare(
        pet: Pet,
        eventID: UUID,
        hygieneLogID: UUID?,
        note: String = "catCare.undo"
    ) -> CatCareUndoCommandResult {
        let result = CatCareCommandService.undo(
            pet: pet,
            eventID: eventID,
            hygieneLogID: hygieneLogID,
            context: context
        )
        deriveCatCareUndo(result, note: note)
        return result
    }

    private func deriveCareRecord(
        _ result: PetCareTrackingCommandResult,
        note: String?
    ) {
        let revisionNote = note ?? "petCareTracking.record.\(result.careType.rawValue)"
        let command = DomainCommand.petCareRecord(
            petID: result.petID,
            type: result.careType.rawValue
        )
        guard result.didRecord else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [result.petID],
                    note: note ?? "petCareTracking.record.noop.\(result.careType.rawValue)"
                )
            )
            return
        }
        var affected: Set<UUID> = [result.petID, result.careLogID]
        if let linkedPottyLogID = result.linkedPottyLogID {
            affected.insert(linkedPottyLogID)
        }
        derivations.derive(
            .active(
                disposition: result.disposition,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: result.petID,
                    logIDs: Array(affected.subtracting([result.petID])),
                    factDate: result.occurredAt,
                    operationDate: result.occurredAt
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: command,
                    affectedEntityIDs: affected,
                    note: revisionNote
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: result.coconutDelta,
                    petDelta: 0
                ),
                noopNote: "\(revisionNote).factOnly"
            )
        )
    }

    private func deriveCareDelete(_ result: PetCareTrackingDeleteCommandResult, note: String) {
        let command = DomainCommand.petCareDelete(petID: result.petID, logID: result.careLogID)
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.careLogID)
        if let linkedPottyLogID = result.linkedPottyLogID {
            affected.insert(linkedPottyLogID)
        }

        guard result.didDelete else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affected,
                    note: "\(note).noop"
                )
            )
            return
        }

        derivations.derive(
            .derivedMutation(
                command: command,
                affectedEntityIDs: affected,
                note: note
            )
        )
    }

    private func derivePottyDelete(_ result: PetPottyDeleteCommandResult, note: String) {
        let command = DomainCommand.petPottyDelete(petID: result.petID, logID: result.logID)
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.logID)

        guard result.didDelete else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affected,
                    note: "\(note).noop"
                )
            )
            return
        }

        derivations.derive(
            .derivedMutation(
                command: command,
                affectedEntityIDs: affected,
                note: note
            )
        )
    }

    private func deriveCatCareRecord(_ result: CatCareCommandResult, note: String) {
        let command = DomainCommand.catCareRecord(petID: result.petID, action: result.actionRaw)
        guard result.didRecord else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [result.petID],
                    note: "\(note).noop"
                )
            )
            return
        }
        var affected: Set<UUID> = [result.petID, result.eventID]
        if let hygieneLogID = result.hygieneLogID {
            affected.insert(hygieneLogID)
        }
        derivations.derive(
            .active(
                disposition: result.disposition,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: result.petID,
                    logIDs: Array(affected.subtracting([result.petID])),
                    factDate: result.occurredAt,
                    operationDate: result.occurredAt
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: command,
                    affectedEntityIDs: affected,
                    note: note
                ),
                noopNote: "\(note).factOnly"
            )
        )
    }

    private func deriveCatCareUndo(_ result: CatCareUndoCommandResult, note: String) {
        let command = DomainCommand.catCareUndo(petID: result.petID, eventID: result.eventID)
        var affected: Set<UUID> = [result.petID, result.eventID]
        if let hygieneLogID = result.hygieneLogID {
            affected.insert(hygieneLogID)
        }
        affected.formUnion(result.removedLedgerEventIDs)

        guard result.didDelete else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affected,
                    note: "\(note).noop"
                )
            )
            return
        }

        derivations.derive(
            .derivedMutation(
                command: command,
                affectedEntityIDs: affected,
                note: note
            )
        )
    }
}
