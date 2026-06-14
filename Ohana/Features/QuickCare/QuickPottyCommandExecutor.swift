//
//  QuickPottyCommandExecutor.swift
//  Ohana
//
//  Write-side boundary for the compact potty check-in sheet.
//

import Foundation
import SwiftData

struct QuickPottyCommandResult: Equatable {
    let petID: UUID
    let careLogID: UUID?
    let pottyLogID: UUID?
    let coconutDelta: Int
    let action: String
    let targetCount: Int
}

@MainActor
private func fetchQuickPottyModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "QuickPottyCommandExecutor failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

@MainActor
struct QuickPottyCommandExecutor {
    private let context: ModelContext
    private let careEvents: CareEventRecording
    private let derivations: CareDerivationExecutor

    init(context: ModelContext) {
        self.init(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            careEvents: CareEventService(),
            revisions: SharedDomainRevisionPublisher(center: revisionCenter)
        )
    }

    init(
        context: ModelContext,
        careEvents: CareEventRecording,
        revisions: DomainRevisionPublishing
    ) {
        self.context = context
        self.careEvents = careEvents
        derivations = CareDerivationExecutor(revisions: revisions)
    }

    func record(
        petID: UUID,
        selectedType: PottyType,
        isLitter: Bool,
        executorId: String?,
        date: Date
    ) -> QuickPottyCommandResult? {
        let action = isLitter ? CareType.litter.rawValue : selectedType.rawValue
        guard let pet = fetchPet(id: petID), EconomyWalletWritePolicy.canWrite(pet) else {
            deriveNoop(petID: petID, action: action, note: "quickPotty.missingPet")
            return nil
        }

        if isLitter {
            let recorded = careEvents.recordCareFact(
                pet: pet,
                type: .litter,
                amountMl: 0,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                quality: .none,
                date: date,
                source: .quickAction,
                createsLinkedPottyLog: false
            )
            guard recorded.result.didWriteFact else {
                deriveNoop(petID: pet.id, action: action, note: "quickPotty.litter.factNoop")
                return nil
            }
            let derivation = derive(
                petID: pet.id,
                action: action,
                affectedIDs: [pet.id, recorded.result.logID],
                logIDs: [recorded.result.logID],
                disposition: recorded.result.disposition,
                reward: recorded.reward,
                date: date,
                note: "quickPotty.litter"
            )
            guard derivation.isUserVisibleSuccess else { return nil }
            return QuickPottyCommandResult(
                petID: pet.id,
                careLogID: recorded.result.logID,
                pottyLogID: nil,
                coconutDelta: recorded.result.coconutDelta,
                action: action,
                targetCount: 1
            )
        }

        let recorded = careEvents.recordPottyFact(
            pet: pet,
            type: selectedType,
            context: context,
            executorId: executorId,
            date: date
        )
        guard recorded.result.didWriteFact else {
            deriveNoop(petID: pet.id, action: action, note: "quickPotty.record.factNoop")
            return nil
        }
        let logID = recorded.result.logID
        var affectedIDs: Set<UUID> = [pet.id]
        if let logID {
            affectedIDs.insert(logID)
        }
        let derivation = derive(
            petID: pet.id,
            action: action,
            affectedIDs: affectedIDs,
            logIDs: logID.map { [$0] } ?? [],
            disposition: recorded.result.disposition,
            reward: recorded.reward,
            date: date,
            note: "quickPotty.record"
        )
        guard derivation.isUserVisibleSuccess else { return nil }
        return QuickPottyCommandResult(
            petID: pet.id,
            careLogID: nil,
            pottyLogID: logID,
            coconutDelta: recorded.reward.humanGot + recorded.reward.petGot,
            action: action,
            targetCount: 1
        )
    }

    func recordUnknownSharedPotty(
        sourcePetID: UUID,
        targetIDs: Set<UUID>,
        type: PottyType,
        executorId: String?,
        date: Date
    ) -> QuickPottyCommandResult? {
        guard let sourcePet = fetchPet(id: sourcePetID), EconomyWalletWritePolicy.canWrite(sourcePet) else {
            deriveNoop(petID: sourcePetID, action: "unknownSharedPotty", note: "quickPotty.unknown.missingPet")
            return nil
        }
        let targets = fetchTargets(sourcePet: sourcePet, targetIDs: targetIDs)
        guard let log = careEvents.recordUnknownSharedPotty(
            sourcePet: sourcePet,
            targets: targets,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        ) else {
            deriveNoop(petID: sourcePet.id, action: "unknownSharedPotty", note: "quickPotty.unknown.factNoop")
            return nil
        }
        let derivation = derive(
            petID: sourcePet.id,
            action: "unknownSharedPotty",
            affectedIDs: Set(targets.map(\.id)).union([sourcePet.id, log.id]),
            logIDs: [log.id],
            disposition: .active,
            reward: (0, 0),
            date: date,
            note: "quickPotty.unknownShared"
        )
        guard derivation.isUserVisibleSuccess else { return nil }
        return QuickPottyCommandResult(
            petID: sourcePet.id,
            careLogID: nil,
            pottyLogID: log.id,
            coconutDelta: 0,
            action: "unknownSharedPotty",
            targetCount: targets.count
        )
    }

    func recordLitterCare(
        sourcePetID: UUID,
        targetIDs: Set<UUID>,
        executorId: String?,
        date: Date,
        isFullChange: Bool
    ) -> QuickPottyCommandResult? {
        guard let sourcePet = fetchPet(id: sourcePetID), EconomyWalletWritePolicy.canWrite(sourcePet) else {
            deriveNoop(petID: sourcePetID, action: isFullChange ? "litterFullChange" : "litterScoop", note: "quickPotty.litter.missingPet")
            return nil
        }
        let targets = fetchTargets(sourcePet: sourcePet, targetIDs: targetIDs)
        let result: SharedPetActionResult?
        let reward: (humanGot: Int, petGot: Int)
        let careLogID: UUID?
        if targets.count > 1 {
            let recorded = careEvents.recordSharedLitterCareFact(
                sourcePet: sourcePet,
                targets: targets,
                context: context,
                executorId: executorId,
                date: date,
                isFullChange: isFullChange
            )
            result = recorded
            reward = recorded.reward
            careLogID = nil
        } else {
            let recorded = careEvents.recordCareFact(
                pet: sourcePet,
                type: .litter,
                amountMl: 0,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                quality: .none,
                date: date,
                source: .quickAction,
                createsLinkedPottyLog: false
            )
            result = nil
            reward = recorded.reward
            careLogID = recorded.result.logID
            guard recorded.result.didWriteFact else {
                let action = isFullChange ? "litterFullChange" : "litterScoop"
                deriveNoop(petID: sourcePet.id, action: action, note: "quickPotty.litterCare.factNoop")
                return nil
            }
        }

        let action = isFullChange ? "litterFullChange" : "litterScoop"
        if let result, !result.didWriteFact {
            deriveNoop(petID: sourcePet.id, action: action, note: "quickPotty.litterCare.factNoop")
            return nil
        }
        var affectedIDs = Set(targets.map(\.id))
        affectedIDs.insert(sourcePet.id)
        if let careLogID {
            affectedIDs.insert(careLogID)
        }
        let derivation = derive(
            petID: sourcePet.id,
            action: action,
            affectedIDs: affectedIDs,
            logIDs: careLogID.map { [$0] } ?? result?.careLogIDs ?? [],
            disposition: result?.disposition ?? .active,
            reward: reward,
            date: date,
            note: isFullChange ? "quickPotty.litterFullChange" : "quickPotty.litterScoop"
        )
        guard derivation.isUserVisibleSuccess else { return nil }
        return QuickPottyCommandResult(
            petID: sourcePet.id,
            careLogID: careLogID,
            pottyLogID: nil,
            coconutDelta: reward.humanGot + reward.petGot,
            action: action,
            targetCount: targets.count
        )
    }

    private func fetchPet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchQuickPottyModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch pet"
        ).first
    }

    private func fetchTargets(sourcePet: Pet, targetIDs: Set<UUID>) -> [Pet] {
        let ids = targetIDs.isEmpty ? [sourcePet.id] : Array(targetIDs)
        let targets = ids.compactMap { fetchPet(id: $0) }
            .filter(EconomyWalletWritePolicy.canWrite)
        return targets.isEmpty ? [sourcePet] : targets
    }

    private func latestPottyLogID(petID: UUID, type: PottyType, date: Date) -> UUID? {
        let typeRaw = type.rawValue
        let lowerBound = date.addingTimeInterval(-0.001)
        let upperBound = date.addingTimeInterval(0.001)
        var descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.pet?.id == petID &&
                    log.type == typeRaw &&
                    log.date >= lowerBound &&
                    log.date <= upperBound
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return fetchQuickPottyModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch latest potty log"
        ).first?.id
    }

    private func derive(
        petID: UUID,
        action: String,
        affectedIDs: Set<UUID>,
        logIDs: [UUID],
        disposition: CareFactWriteDisposition,
        reward: (humanGot: Int, petGot: Int),
        date: Date,
        note: String
    ) -> CareDerivationResult {
        derivations.derive(
            .active(
                disposition: disposition,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: petID,
                    logIDs: logIDs,
                    factDate: date,
                    operationDate: date
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: .quickCare(entityID: petID, action: action),
                    affectedEntityIDs: affectedIDs,
                    note: note
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: reward.humanGot,
                    petDelta: reward.petGot
                ),
                noopNote: "\(note).factOnly"
            )
        )
    }

    private func deriveNoop(petID: UUID, action: String, note: String) {
        derivations.derive(
            .noOp(
                command: .quickCare(entityID: petID, action: action),
                affectedEntityIDs: [petID],
                note: note
            )
        )
    }
}
