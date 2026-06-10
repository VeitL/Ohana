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
}

struct PetCareTrackingDeleteCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID
    let linkedPottyLogID: UUID?
    let removedLedgerEventIDs: [UUID]
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
            return (
                PetCareTrackingCommandResult(
                    petID: pet.id,
                    careLogID: recorded.result.logID,
                    linkedPottyLogID: nil,
                    careType: .feeding,
                    coconutDelta: recorded.result.coconutDelta
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
        return (
            PetCareTrackingCommandResult(
                petID: pet.id,
                careLogID: recorded.result.logID,
                linkedPottyLogID: recorded.result.linkedPottyLogID,
                careType: type,
                coconutDelta: recorded.result.coconutDelta
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
        let linkedPotty = linkedPottyLog(for: log, pet: pet, context: context)
        var removedLedgerEvents = ledgerEvents(forLegacyModelName: "PetCareLog", id: careLogID, context: context)
        if let linkedPotty {
            removedLedgerEvents += ledgerEvents(forLegacyModelName: "PetPottyLog", id: linkedPotty.id, context: context)
        }

        for event in removedLedgerEvents {
            context.delete(event)
        }
        if let linkedPotty {
            context.delete(linkedPotty)
        }
        context.delete(log)
        context.safeSave()

        return PetCareTrackingDeleteCommandResult(
            petID: pet.id,
            careLogID: careLogID,
            linkedPottyLogID: linkedPotty?.id,
            removedLedgerEventIDs: removedLedgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func linkedPottyLog(for log: PetCareLog, pet: Pet, context: ModelContext) -> PetPottyLog? {
        guard log.careType == .litter else { return nil }
        let logs = (try? context.fetch(FetchDescriptor<PetPottyLog>())) ?? []
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
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }

    private static func reward(for type: CareType, pet: Pet) -> QuestManager.OhanaActionType {
        switch type {
        case .feeding:
            return .feed
        case .watering:
            return .water
        case .litter:
            return .potty(isLitter: true)
        case .play:
            return .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 互动奖励")
        case .filterClean:
            return .general(humanReward: 25, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理滤材报酬")
        case .cageCleaning:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 清理鸟笼奖励")
        case .freeFlight:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 放飞互动奖励")
        case .misting:
            return .general(humanReward: 3, petReward: 2, emoji: type.emoji, title: "\(pet.name) 保湿打卡奖励")
        case .substrateChange:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 环境清洁奖励")
        case .waterChange:
            return .general(humanReward: 10, petReward: 2, emoji: type.emoji, title: "\(pet.name) 换水奖励")
        }
    }
}

struct PetPottyDeleteCommandResult: Equatable {
    let petID: UUID
    let logID: UUID
    let removedLedgerEventIDs: [UUID]
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
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetPottyLog", id: logID, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        context.delete(log)
        context.safeSave()
        return PetPottyDeleteCommandResult(
            petID: pet.id,
            logID: logID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? []
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }
}

@MainActor
struct PetCareCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

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
        revisions.publishPetCareRecord(
            recorded.result,
            note: note ?? "petCareTracking.record.\(recorded.result.careType.rawValue)"
        )
        return recorded
    }

    @discardableResult
    func deleteCareLog(
        _ log: PetCareLog,
        pet: Pet,
        note: String
    ) -> PetCareTrackingDeleteCommandResult {
        let result = PetCareTrackingCommandService.deleteCareLog(log, pet: pet, context: context)
        revisions.publishPetCareDelete(result, note: note)
        return result
    }

    @discardableResult
    func deletePottyLog(
        _ log: PetPottyLog,
        pet: Pet,
        note: String
    ) -> PetPottyDeleteCommandResult {
        let result = PetPottyCommandService.deletePottyLog(log, pet: pet, context: context)
        revisions.publishPetPottyDelete(result, note: note)
        return result
    }

    @discardableResult
    func recordCatCare(
        pet: Pet,
        input: CatCareCommandInput,
        note: String = "catCare.record"
    ) -> CatCareCommandResult {
        let result = CatCareCommandService.record(pet: pet, input: input, context: context)
        revisions.publishCatCareRecord(result, note: note)
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
        revisions.publishCatCareUndo(result, note: note)
        return result
    }
}
